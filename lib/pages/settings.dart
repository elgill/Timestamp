import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _launchURL(String url) async {
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Settings")),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Privacy Policy'),
            onTap: () {
              _launchURL('https://gillin.dev/privacy');
            },
          ),
/*          ListTile(
            title: const Text('Terms of Service'),
            onTap: () {
              _launchURL('https://gillin.dev');
            },
          ),*/
          ListTile(
            title: const Text('Feedback & Support'),
            onTap: () {
              _launchURL('https://gillin.dev/#contact');
            },
          ),
          const ListTile(
            title: Text('App Version'),
            subtitle: Text('1.0.0'), // replace with dynamic app version
          ),
          // Any other settings can be added here
        ],
      ),
    );
  }
}
