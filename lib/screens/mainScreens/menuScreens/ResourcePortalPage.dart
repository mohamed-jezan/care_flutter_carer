import 'package:flutter/material.dart';

class ResourcePortalPage extends StatefulWidget {
  const ResourcePortalPage({super.key});

  @override
  State<ResourcePortalPage> createState() => _ResourcePortalPageState();
}

class _ResourcePortalPageState extends State<ResourcePortalPage> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('No resources available at the moment.'),
      ),
    );
  }
}