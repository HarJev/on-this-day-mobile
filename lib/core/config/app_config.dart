class AppConfig {
  const AppConfig({required this.apiBaseUrl});

  factory AppConfig.fromEnvironment() {
    const configuredBaseUrl = String.fromEnvironment(
      'ON_THIS_DAY_API_BASE_URL',
      defaultValue: 'http://127.0.0.1:3000',
    );

    return AppConfig(apiBaseUrl: Uri.parse(configuredBaseUrl));
  }

  final Uri apiBaseUrl;
}
