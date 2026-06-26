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
  final GlobalKey<ScaffoldState> _scaffoldKey =
      GlobalKey<ScaffoldState>();

  static const Color primaryColor =
      Color.fromARGB(255, 255, 126, 126);

  int currentIndex = 1;

  final List<Widget> screens = [
    const MapScreen(), //0
    const DashboardPage(), //1
    const UpdatesPage(), //2
    const OffersPage(), //3
    const SchedulePage(), //4
    const ResourcePortalPage(), //5
    const CalendarPage(), //6
    const EarningsPage(), //7
    const SettingsPage(), //8
    const HelpPage(), //9
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
      key: _scaffoldKey,

      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        backgroundColor: primaryColor,
        title: Text(
          titles[currentIndex],
          style: const TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w700,
          ),
        ),
        iconTheme: const IconThemeData(
          color: Colors.black87,
        ),
      ),

      endDrawer: _buildDrawer(),

      body: screens[currentIndex],

      bottomNavigationBar: SafeArea(
        child: Container(
          height: 75,
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              _bottomItem(
                Icons.dashboard_rounded,
                "Dashboard",
                1,
              ),

              _bottomItem(
                Icons.schedule_rounded,
                "Schedule",
                4,
              ),

              _bottomItem(
                Icons.map_rounded,
                "Map",
                0,
              ),

              _bottomItem(
                Icons.payments_rounded,
                "Earnings",
                7,
              ),

              _bottomItem(
                Icons.menu_rounded,
                "More",
                -1,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomItem(
    IconData icon,
    String label,
    int index,
  ) {
    bool selected = currentIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (index == -1) {
            _scaffoldKey.currentState?.openEndDrawer();
            return;
          }

          setState(() {
            currentIndex = index;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 8,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 24,
                color: selected
                    ? primaryColor
                    : Colors.grey,
              ),

              const SizedBox(height: 4),

              Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: selected
                      ? FontWeight.w600
                      : FontWeight.normal,
                  color: selected
                      ? primaryColor
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [

          const DrawerHeader(
            decoration: BoxDecoration(
              color: primaryColor,
            ),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(
                    'assets/images/1.jpg',
                  ),
                ),

                SizedBox(height: 12),

                Text(
                  'Mohamed Jezan',
                  style: TextStyle(
                    color: Colors.black87,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),

          _drawerTile(
            Icons.update,
            'Updates',
            2,
          ),

          _drawerTile(
            Icons.local_offer,
            'Offers',
            3,
          ),

          _drawerTile(
            Icons.folder,
            'Resource Portal',
            5,
          ),

          _drawerTile(
            Icons.calendar_today,
            'Calendar',
            6,
          ),

          _drawerTile(
            Icons.settings,
            'Settings',
            8,
          ),

          _drawerTile(
            Icons.help,
            'Help',
            9,
          ),
        ],
      ),
    );
  }

  Widget _drawerTile(
    IconData icon,
    String title,
    int index,
  ) {
    return ListTile(
      leading: Icon(
        icon,
        color: primaryColor,
      ),
      title: Text(title),
      onTap: () {
        setState(() {
          currentIndex = index;
        });

        Navigator.pop(context);
      },
    );
  }
}