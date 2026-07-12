import 'package:flutter/material.dart';

/// A navigation destination shared by the bottom bar (narrow layouts)
/// and the navigation rail (wide layouts).
class ResponsiveDestination {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const ResponsiveDestination({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

/// Scaffold that adapts its navigation to the screen width:
/// below [breakpoint] it shows a [BottomNavigationBar] (mobile),
/// at or above it a [NavigationRail] (tablet/desktop/web), which
/// becomes an extended sidebar on very wide screens.
class ResponsiveScaffold extends StatelessWidget {
  static const double breakpoint = 768;
  static const double extendedBreakpoint = 1200;

  final PreferredSizeWidget? appBar;
  final Widget body;
  final List<ResponsiveDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final Widget? floatingActionButton;
  final Widget? drawer;

  const ResponsiveScaffold({
    super.key,
    this.appBar,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.floatingActionButton,
    this.drawer,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= breakpoint;
        final isExtended = constraints.maxWidth >= extendedBreakpoint;

        if (!isWide) {
          return Scaffold(
            appBar: appBar,
            drawer: drawer,
            body: body,
            floatingActionButton: floatingActionButton,
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: selectedIndex,
              onTap: onDestinationSelected,
              type: BottomNavigationBarType.fixed,
              items: destinations
                  .map((d) => BottomNavigationBarItem(
                        icon: Icon(d.icon),
                        activeIcon: Icon(d.activeIcon),
                        label: d.label,
                      ))
                  .toList(),
            ),
          );
        }

        return Scaffold(
          appBar: appBar,
          drawer: drawer,
          floatingActionButton: floatingActionButton,
          body: Row(
            children: [
              NavigationRail(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                extended: isExtended,
                labelType: isExtended
                    ? NavigationRailLabelType.none
                    : NavigationRailLabelType.all,
                destinations: destinations
                    .map((d) => NavigationRailDestination(
                          icon: Icon(d.icon),
                          selectedIcon: Icon(d.activeIcon),
                          label: Text(d.label),
                        ))
                    .toList(),
              ),
              const VerticalDivider(thickness: 1, width: 1),
              Expanded(child: body),
            ],
          ),
        );
      },
    );
  }
}
