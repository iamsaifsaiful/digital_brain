package com.iamsaifsaiful.my_assistant_admin

import android.app.Activity
import android.content.Intent
import android.os.CancellationSignal
import androidx.core.content.ContextCompat
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CredentialManager
import androidx.credentials.CredentialManagerCallback
import androidx.credentials.CustomCredential
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetCredentialResponse
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.ApiException
import com.google.android.gms.common.api.CommonStatusCodes
import com.google.android.gms.common.api.Scope
import com.google.android.libraries.identity.googleid.GetSignInWithGoogleOption
import com.google.android.libraries.identity.googleid.GoogleIdTokenCredential
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "my_assistant/google": Sign in with Google (Credential Manager) and an
 * access token for the app's own hidden Drive folder (drive.appdata only —
 * the app never sees the user's other Drive files).
 *
 * Needs, in Google Cloud: an OAuth "Web client" (its ID is passed from Dart)
 * and an "Android" client with this app's package name and signing SHA-1.
 * Without them Google answers DEVELOPER_ERROR, reported to Dart as "setup".
 */
class GoogleAuth(private val activity: Activity) {
    private var driveResult: MethodChannel.Result? = null

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "signIn" -> signIn(call.argument<String>("webClientId") ?: "", result)
            "driveToken" -> driveToken(result)
            "signOut" -> signOut(result)
            else -> result.notImplemented()
        }
    }

    private fun signIn(webClientId: String, result: MethodChannel.Result) {
        if (webClientId.isEmpty()) {
            result.error("setup", "no web client id", null)
            return
        }
        val option = GetSignInWithGoogleOption.Builder(webClientId).build()
        val request = GetCredentialRequest.Builder().addCredentialOption(option).build()
        try {
            CredentialManager.create(activity).getCredentialAsync(
                activity,
                request,
                CancellationSignal(),
                ContextCompat.getMainExecutor(activity),
                object : CredentialManagerCallback<GetCredentialResponse, GetCredentialException> {
                    override fun onResult(response: GetCredentialResponse) {
                        val c = response.credential
                        if (c is CustomCredential && c.type == GoogleIdTokenCredential.TYPE_GOOGLE_ID_TOKEN_CREDENTIAL) {
                            try {
                                val g = GoogleIdTokenCredential.createFrom(c.data)
                                result.success(
                                    mapOf(
                                        "id" to g.id,
                                        "email" to g.id,
                                        "name" to (g.displayName ?: ""),
                                        "photo" to (g.profilePictureUri?.toString() ?: ""),
                                        "idToken" to g.idToken,
                                    ),
                                )
                            } catch (e: Exception) {
                                result.error("error", e.message, null)
                            }
                        } else {
                            result.error("error", "unexpected credential", null)
                        }
                    }

                    override fun onError(e: GetCredentialException) {
                        val text = "${e.type} ${e.message}"
                        when {
                            e is GetCredentialCancellationException -> result.error("cancelled", e.message, null)
                            e is NoCredentialException -> result.error("no_account", "No Google account on this phone", null)
                            text.contains("28444") || text.contains("10:") || text.contains("DEVELOPER", ignoreCase = true) ->
                                result.error("setup", e.message, null)
                            text.contains("network", ignoreCase = true) -> result.error("network", e.message, null)
                            else -> result.error("error", e.message, null)
                        }
                    }
                },
            )
        } catch (e: Exception) {
            result.error("error", e.message, null)
        }
    }

    private fun driveToken(result: MethodChannel.Result) {
        val request = AuthorizationRequest.builder()
            .setRequestedScopes(listOf(Scope(DRIVE_APPDATA)))
            .build()
        Identity.getAuthorizationClient(activity).authorize(request)
            .addOnSuccessListener { ar ->
                val pending = ar.pendingIntent
                if (ar.hasResolution() && pending != null) {
                    driveResult?.error("cancelled", "replaced", null)
                    driveResult = result
                    try {
                        activity.startIntentSenderForResult(pending.intentSender, DRIVE_REQUEST, null, 0, 0, 0, null)
                    } catch (e: Exception) {
                        driveResult = null
                        result.error("error", e.message, null)
                    }
                } else {
                    result.success(ar.accessToken)
                }
            }
            .addOnFailureListener { e -> result.error(codeOf(e), e.message, null) }
    }

    /** From MainActivity.onActivityResult. */
    fun onActivityResult(requestCode: Int, data: Intent?): Boolean {
        if (requestCode != DRIVE_REQUEST) return false
        val r = driveResult ?: return true
        driveResult = null
        try {
            val ar = Identity.getAuthorizationClient(activity).getAuthorizationResultFromIntent(data)
            r.success(ar.accessToken)
        } catch (e: Exception) {
            r.error(codeOf(e), e.message, null)
        }
        return true
    }

    private fun signOut(result: MethodChannel.Result) {
        try {
            CredentialManager.create(activity).clearCredentialStateAsync(
                ClearCredentialStateRequest(),
                CancellationSignal(),
                ContextCompat.getMainExecutor(activity),
                object : CredentialManagerCallback<Void?, ClearCredentialException> {
                    override fun onResult(r: Void?) {
                        result.success(null)
                    }

                    override fun onError(e: ClearCredentialException) {
                        result.success(null)
                    }
                },
            )
        } catch (e: Exception) {
            result.success(null)
        }
    }

    private fun codeOf(e: Exception): String = when {
        e is ApiException && e.statusCode == CommonStatusCodes.DEVELOPER_ERROR -> "setup"
        e is ApiException && e.statusCode == CommonStatusCodes.CANCELED -> "cancelled"
        e is ApiException && e.statusCode == CommonStatusCodes.NETWORK_ERROR -> "network"
        else -> "error"
    }

    companion object {
        const val DRIVE_REQUEST = 4714
        const val DRIVE_APPDATA = "https://www.googleapis.com/auth/drive.appdata"
    }
}
