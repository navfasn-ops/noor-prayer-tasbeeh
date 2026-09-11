import 'package:flutter/material.dart';

void main() {
  runApp(const NoorApp());
}

class NoorApp extends StatelessWidget {
  const NoorApp({super.key});

  static const gold = Color(0xFFD4AF37);
  static const darkGreen = Color(0xFF061A16);
  static const cardGreen = Color(0xFF0B241F);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Noor Prayer & Tasbeeh',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkGreen,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          brightness: Brightness.dark,
        ),
        fontFamily: 'Arial',
      ),
      home: const NoorShell(),
    );
  }
}


class PrayerPage extends StatefulWidget {
  const PrayerPage({super.key});
    @override
  State<PrayerPage> createState() => _PrayerPageState();
}
  class _PrayerPageState extends State<PrayerPage> {
      @override
 void initState() {
  super.initState();
  _loadPrayerTimes();
}
    Future<void> _loadPrayerTimes() async {
    final locationService = LocationService();
    final position = await locationService.getCurrentPosition();
    final prayerService = PrayerService();

    final prayerTimes = await prayerService.getPrayerTimes(
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NoorApp.darkGreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Prayer Times',
                    style: TextStyle(
                      color: NoorApp.gold,
                      fontSize: 30,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Prayer Times & Iqamah',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0x33152F29),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0x44D4AF37),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Icon(
                          Icons.mosque_outlined,
                          color: NoorApp.gold,
                          size: 48,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Loading Prayer Times...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          'Preparing your daily prayer schedule',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  const Row(
                    children: [
                      Expanded(
                        child: _PrayerTimeCard(
                          icon: Icons.nightlight_round,
                          name: 'Fajr',
                          time: '--:--',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _PrayerTimeCard(
                          icon: Icons.wb_sunny_outlined,
                          name: 'Dhuhr',
                          time: '--:--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const Row(
                    children: [
                      Expanded(
                        child: _PrayerTimeCard(
                          icon: Icons.wb_twilight,
                          name: 'Asr',
                          time: '--:--',
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _PrayerTimeCard(
                          icon: Icons.wb_sunny,
                          name: 'Maghrib',
                          time: '--:--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  const _PrayerTimeCard(
                    icon: Icons.dark_mode_outlined,
                    name: 'Isha',
                    time: '--:--',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrayerTimeCard extends StatelessWidget {
  final IconData icon;
  final String name;
  final String time;

  const _PrayerTimeCard({
    required this.icon,
    required this.name,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x22152F29),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x3322D4AF),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: NoorApp.gold,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class NoorShell extends StatefulWidget {
  const NoorShell({super.key});

  @override
  State<NoorShell> createState() => _NoorShellState();
}

class _NoorShellState extends State<NoorShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    NoorHomePage(),
    PrayerPage(),
    SectionPage(
      icon: Icons.radio_button_checked,
      title: 'Tasbeeh',
      subtitle: 'Personal & After Prayer Dhikr',
    ),
    SectionPage(
      icon: Icons.menu_book_outlined,
      title: 'Quran',
      subtitle: 'Complete Quran',
    ),
    SectionPage(
      icon: Icons.auto_stories_outlined,
      title: 'Duas',
      subtitle: 'Duas & Adhkar',
    ),
  ];

  final List<NavigationDestination> _destinations = const [
    NavigationDestination(
      icon: Icon(Icons.home_outlined),
      selectedIcon: Icon(Icons.home),
      label: 'Home',
    ),
    NavigationDestination(
      icon: Icon(Icons.mosque_outlined),
      selectedIcon: Icon(Icons.mosque),
      label: 'Prayer',
    ),
    NavigationDestination(
      icon: Icon(Icons.radio_button_unchecked),
      selectedIcon: Icon(Icons.radio_button_checked),
      label: 'Tasbeeh',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'Quran',
    ),
    NavigationDestination(
      icon: Icon(Icons.auto_stories_outlined),
      selectedIcon: Icon(Icons.auto_stories),
      label: 'Duas',
    ),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isLargeScreen = constraints.maxWidth >= 600;

        if (isLargeScreen) {
          return Scaffold(
            body: Row(
              children: [
                _buildNavigationRail(),
                Expanded(
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: _pages,
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          body: IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          bottomNavigationBar: _buildNavigationBar(),
        );
      },
    );
  }

  Widget _buildNavigationBar() {
    return NavigationBar(
      height: 80,
      selectedIndex: _selectedIndex,
      onDestinationSelected: _onDestinationSelected,
      backgroundColor: const Color(0xFF0B241F),
      indicatorColor: const Color(0x55D4AF37),
      elevation: 12,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: _destinations,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: NoorApp.gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: Color(0xFFFFFFFF),
            fontSize: 11,
          );
        },
      ),
    );
  }

  Widget _buildNavigationRail() {
    return Container(
      width: 96,
      decoration: const BoxDecoration(
        color: Color(0xF20B241F),
        border: Border(
          right: BorderSide(
            color: Color(0x332A2A2A),
          ),
        ),
      ),
      child: NavigationRail(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        backgroundColor: Colors.transparent,
        labelType: NavigationRailLabelType.all,
        selectedIconTheme: const IconThemeData(
          color: NoorApp.gold,
          size: 25,
        ),
        unselectedIconTheme: const IconThemeData(
          color: Color(0x99FFFFFF),
          size: 23,
        ),
        selectedLabelTextStyle: const TextStyle(
          color: NoorApp.gold,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: const TextStyle(
          color: Color(0x99FFFFFF),
          fontSize: 11,
        ),
        indicatorColor: const Color(0x33D4AF37),
        destinations: _destinations
            .map(
              (destination) => NavigationRailDestination(
                icon: destination.icon,
                selectedIcon: destination.selectedIcon,
                label: Text(destination.label),
              ),
            )
            .toList(),
      ),
    );
  }
}

class SectionPage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const SectionPage({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0x221B4D42),
                  border: Border.all(
                    color: const Color(0x55D4AF37),
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x33000000),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: NoorApp.gold,
                  size: 44,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Coming next',
                style: TextStyle(
                  color: Color(0x99D4AF37),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NoorHomePage extends StatelessWidget {
  const NoorHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double horizontalPadding =
            constraints.maxWidth < 500
                ? 16
                : constraints.maxWidth < 900
                    ? 28
                    : 40;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF061A16),
                Color(0xFF081F1A),
                Color(0xFF04130F),
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                24,
                horizontalPadding,
                30,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 1000,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildDateCard(),
                      const SizedBox(height: 18),
                      _buildNextPrayerCard(),
                      const SizedBox(height: 28),
                      const Text(
                        'Quick Access',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _buildQuickGrid(constraints.maxWidth),
                      const SizedBox(height: 30),
                      const Center(
                        child: Text(
                          'Created by Safwan',
                          style: TextStyle(
                            color: Color(0x88D4AF37),
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            color: const Color(0x331B4D42),
            border: Border.all(
              color: const Color(0x44D4AF37),
            ),
          ),
          child: const Icon(
            Icons.nightlight_round,
            color: NoorApp.gold,
            size: 25,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Assalamu Alaikum',
                style: TextStyle(
                  color: Color(0xFFD9D9D9),
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Noor Prayer & Tasbeeh',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateCard() {
    return _glassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Friday, 11 September 2026',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '29 Rabi al-Awwal 1448 AH',
            style: TextStyle(
              color: NoorApp.gold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: const [
              Icon(
                Icons.location_on_outlined,
                color: NoorApp.gold,
                size: 18,
              ),
              SizedBox(width: 7),
              Text(
                'Location',
                style: TextStyle(
                  color: Color(0xBBD9D9D9),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNextPrayerCard() {
    return _glassCard(
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0x22D4AF37),
              border: Border.all(
                color: const Color(0x55D4AF37),
              ),
            ),
            child: const Icon(
              Icons.nightlight_outlined,
              color: NoorApp.gold,
              size: 27,
            ),
          ),
          const SizedBox(width: 15),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Prayer',
                  style: TextStyle(
                    color: Color(0xAAD9D9D9),
                    fontSize: 12,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Fajr',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Text(
            '--:--',
            style: TextStyle(
              color: NoorApp.gold,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildQuickGrid(double width) {
    final int columns = width < 600 ? 2 : 3;

    final items = [
      const _QuickItem(
        icon: Icons.radio_button_checked,
        title: 'Tasbeeh',
        subtitle: 'Dhikr & Counter',
      ),
      const _QuickItem(
        icon: Icons.menu_book_outlined,
        title: 'Quran',
        subtitle: 'Read Quran',
      ),
      const _QuickItem(
        icon: Icons.explore_outlined,
        title: 'Qibla',
        subtitle: 'Find Qibla',
      ),
      const _QuickItem(
        icon: Icons.auto_stories_outlined,
        title: 'Duas',
        subtitle: 'Duas & Adhkar',
      ),
      const _QuickItem(
        icon: Icons.calendar_month_outlined,
        title: 'Calendar',
        subtitle: 'Hijri Calendar',
      ),
      const _QuickItem(
        icon: Icons.access_time_outlined,
        title: 'Prayer',
        subtitle: 'Prayer Times',
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: width < 600 ? 1.45 : 1.8,
      ),
      itemBuilder: (context, index) {
        return _QuickCard(item: items[index]);
      },
    );
  }

  Widget _glassCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0x331B4D42),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0x33D4AF37),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String title;
  final String subtitle;

  const _QuickItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _QuickCard extends StatelessWidget {
  final _QuickItem item;

  const _QuickCard({
    required this.item,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0x331B4D42),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0x2ED4AF37),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0x22D4AF37),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: const Color(0x44D4AF37),
              ),
            ),
            child: Icon(
              item.icon,
              color: NoorApp.gold,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0x99D9D9D9),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
