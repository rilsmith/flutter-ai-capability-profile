import 'package:url_launcher/url_launcher.dart';

Future<void> openUrl(String url) async {
  await launchUrl(Uri.parse(url));
}
