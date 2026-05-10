import 'package:flutter/material.dart';
import 'menuScreens/DashboardPage.dart';
import 'menuScreens/UpdatesPage.dart';
import 'menuScreens/EarningsPage.dart';
import 'menuScreens/OffersPage.dart';
import 'menuScreens/SchedulePage.dart';
import 'menuScreens/ResourcePortalPage.dart';
import 'menuScreens/CalendarPage.dart';
import 'menuScreens/SettingsPage.dart';
import 'menuScreens/HelpPage.dart';
import 'mapScreens/mapScreen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int currentIndex = 1;

  final List<Widget> screens = [
    const MapScreen(),
    const DashboardPage(),
    const UpdatesPage(),
    const OffersPage(),
    const SchedulePage(),
    const ResourcePortalPage(),
    const CalendarPage(),
    const EarningsPage(),
    const SettingsPage(),
    const HelpPage(),
  ];

  final List<String> titles = [
    'Map',
    'Dashboard',
    'Updates',
    'Offers',
    'Schedule',
    'Resource Portal',
    'Calendar',
    'Earnings',
    'Settings', 
    'Help',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 255, 126, 126),
        title: Text(
          (titles[currentIndex]),
          style: const TextStyle(color: Colors.black87),
        ),
        centerTitle: true,
        
      ),
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Color.fromARGB(255, 255, 126, 126),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 40,
                    backgroundImage: AssetImage('assets/images/1.jpg'),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Mohamed Jezan',
                    style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                  ),
                ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                setState(() {
                  currentIndex = 0;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Your Dashboard'),
              onTap: () {
                setState(() {
                  currentIndex = 1;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Updates'),
              onTap: () {
                setState(() {
                  currentIndex = 2;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_offer),
              title: const Text('Offers'),
              onTap: () {
                setState(() {
                  currentIndex = 3;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Schedule'),
              onTap: () {
                setState(() {
                  currentIndex = 4;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder),
              title: const Text('Resource Portal'),
              onTap: () {
                setState(() {
                  currentIndex = 5;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Calender'),
              onTap: () {
                setState(() {
                  currentIndex = 6;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.monetization_on),
              title: const Text('Earnings'),
              onTap: () {
                setState(() {
                  currentIndex = 7;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings),
              title: const Text('Settings'),
              onTap: () {
                setState(() {
                  currentIndex = 8;
                });
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.help),
              title: const Text('Help'),
              onTap: () {
                setState(() {
                  currentIndex = 9;
                });
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      ) ,
      body: screens[currentIndex]
    );
  }
}