package com.iamsaifsaiful.digital_brain

import android.app.Activity
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * "my_assistant/billing": Google Play subscriptions (Premium) for the Play app.
 * The phone only buys and lists; our server checks every purchase with Google
 * and acknowledges it (play.php), so nothing here turns Premium on by itself.
 */
class PlayBilling(private val activity: Activity) : PurchasesUpdatedListener {
    private val main = Handler(Looper.getMainLooper())
    private val client: BillingClient = BillingClient.newBuilder(activity)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .build()
    private var buying: MethodChannel.Result? = null
    private var buyingProduct = ""

    private fun ui(block: () -> Unit) = main.post(block)

    /** Connects to Play when needed, then runs [then] (false when Play is not there). */
    private fun ready(then: (Boolean) -> Unit) {
        if (client.isReady) {
            then(true)
            return
        }
        try {
            client.startConnection(object : BillingClientStateListener {
                override fun onBillingSetupFinished(r: BillingResult) {
                    ui { then(r.responseCode == BillingClient.BillingResponseCode.OK) }
                }

                override fun onBillingServiceDisconnected() {}
            })
        } catch (e: Exception) {
            then(false)
        }
    }

    private fun details(ids: List<String>, then: (List<ProductDetails>) -> Unit) {
        val params = QueryProductDetailsParams.newBuilder().setProductList(ids.map {
            QueryProductDetailsParams.Product.newBuilder().setProductId(it).setProductType(BillingClient.ProductType.SUBS).build()
        }).build()
        // Billing 8 (Google Play asks for 8.0.0 or newer, 29 Oct): the answer comes as a result object.
        client.queryProductDetailsAsync(params) { r, result ->
            ui { then(if (r.responseCode == BillingClient.BillingResponseCode.OK) result.productDetailsList else emptyList()) }
        }
    }

    /** The base plan's offer (no trial or discount offers of our own). */
    private fun offer(pd: ProductDetails): ProductDetails.SubscriptionOfferDetails? {
        val offers = pd.subscriptionOfferDetails ?: return null
        return offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull()
    }

    private fun purchaseMap(p: Purchase): Map<String, Any> = mapOf(
        "product" to (p.products.firstOrNull() ?: ""),
        "token" to p.purchaseToken,
        "acknowledged" to p.isAcknowledged,
    )

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "prices" -> {
                val ids = call.argument<List<String>>("products") ?: emptyList()
                ready { ok ->
                    if (!ok || ids.isEmpty()) {
                        result.success(emptyMap<String, String>())
                        return@ready
                    }
                    details(ids) { list ->
                        val out = HashMap<String, String>()
                        for (pd in list) {
                            val phase = offer(pd)?.pricingPhases?.pricingPhaseList?.lastOrNull() ?: continue
                            out[pd.productId] = phase.formattedPrice
                        }
                        result.success(out)
                    }
                }
            }
            "buy" -> {
                val product = call.argument<String>("product") ?: ""
                val account = call.argument<String>("account") ?: ""
                if (buying != null) {
                    result.success(mapOf("result" to "error", "message" to "আগের কেনা এখনো চলছে"))
                    return
                }
                ready { ok ->
                    if (!ok) {
                        result.success(mapOf("result" to "error", "message" to "এই ফোনে Google Play পাওয়া যায়নি"))
                        return@ready
                    }
                    details(listOf(product)) { list ->
                        val pd = list.firstOrNull()
                        val o = pd?.let { offer(it) }
                        if (pd == null || o == null) {
                            result.success(mapOf("result" to "error", "message" to "Google Play-তে প্ল্যানটা পাওয়া যায়নি — পরে আবার চেষ্টা করুন"))
                            return@details
                        }
                        val flow = BillingFlowParams.newBuilder()
                            .setProductDetailsParamsList(listOf(BillingFlowParams.ProductDetailsParams.newBuilder().setProductDetails(pd).setOfferToken(o.offerToken).build()))
                            .apply { if (account.isNotEmpty()) setObfuscatedAccountId(account.take(64)) }
                            .build()
                        buying = result
                        buyingProduct = product
                        val r = client.launchBillingFlow(activity, flow)
                        if (r.responseCode != BillingClient.BillingResponseCode.OK) {
                            buying = null
                            result.success(answerFor(r, null))
                        }
                    }
                }
            }
            "owned" -> ready { ok ->
                if (!ok) {
                    result.success(emptyList<Map<String, Any>>())
                    return@ready
                }
                client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()) { r, purchases ->
                    ui {
                        result.success(if (r.responseCode == BillingClient.BillingResponseCode.OK)
                            purchases.filter { it.purchaseState == Purchase.PurchaseState.PURCHASED }.map { purchaseMap(it) }
                        else emptyList())
                    }
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun answerFor(r: BillingResult, purchases: List<Purchase>?): Map<String, Any> = when (r.responseCode) {
        BillingClient.BillingResponseCode.OK -> {
            val p = purchases?.firstOrNull { it.products.contains(buyingProduct) } ?: purchases?.firstOrNull()
            when {
                p == null -> mapOf("result" to "error")
                p.purchaseState == Purchase.PurchaseState.PENDING -> mapOf("result" to "pending")
                else -> mapOf("result" to "bought") + purchaseMap(p)
            }
        }
        BillingClient.BillingResponseCode.USER_CANCELED -> mapOf("result" to "cancelled")
        BillingClient.BillingResponseCode.ITEM_ALREADY_OWNED -> mapOf("result" to "owned")
        else -> mapOf("result" to "error")
    }

    override fun onPurchasesUpdated(r: BillingResult, purchases: MutableList<Purchase>?) {
        ui {
            val pending = buying ?: return@ui
            buying = null
            pending.success(answerFor(r, purchases))
        }
    }
}
