# রিয়াল-বিকাশ হিসাব

সৌদি থেকে বিকাশ/নগদে টাকা পাঠানোর খাতা। গ্রাহকের হিসাব শুধু রিয়ালে,
এজেন্টের হিসাব শুধু টাকায়। প্রতিটা লেনদেনে রিয়াল আর রেট দিলে টাকা নিজে
হিসাব হয়; মেসেজ এজেন্টের একই হোয়াটসঅ্যাপ চ্যাটে যায় (রিয়ালের কথা নেই),
এজেন্ট রিপ্লাইতে TrxID দিলে সেটা কপি করে অ্যাপে ফিরলেই বসে যায়।

APK: এই ব্রাঞ্চে push হলে GitHub Actions বানায় এবং
[Releases](https://github.com/iamsaifsaiful/digital_brain/releases)-এ
`riyal-hisab-v…` নামে pre-release হিসেবে রাখে (My Assistant-এর latest লিংক বদলায় না)।

হাতে চালাতে:

```
bash tool/setup_platforms.sh
flutter pub get
flutter test
flutter run
```

বিস্তারিত: [docs/HANDOFF.md](docs/HANDOFF.md)
