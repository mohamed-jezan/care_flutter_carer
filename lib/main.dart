import 'package:call_care/screens/startup_page.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  print("Loaded API URL: ${dotenv.env['BASE_URL']}");
  runApp(const CallCareApp());
}

class CallCareApp extends StatelessWidget {
  const CallCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Call Care',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const StartupPage(),
    );
  }
}