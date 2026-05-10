class OnboardingBankDetails {
  final bool success;
  final String message;
  final String stripeAccountId;
  final String onboardingUrl;
  final Map<String, dynamic>? dbRecord;

  OnboardingBankDetails({
    required this.success,
    required this.message,
    required this.stripeAccountId,
    required this.onboardingUrl,
    this.dbRecord,
  });

  factory OnboardingBankDetails.fromJson(Map<String, dynamic> json) {
    return OnboardingBankDetails(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      stripeAccountId: json['stripe_account_id'] ?? '',
      onboardingUrl: json['onboarding_url'] ?? '',
      dbRecord: json['db_record'],
    );
  }
}