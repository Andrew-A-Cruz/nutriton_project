import 'package:flutter/cupertino.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
   return CupertinoApp(
      home: HomeScreen(),
   );
}
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context){
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.book_solid),
            label: ('Articles'),
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.eye_solid),
            label: ('Views'),
            ),
        ]),
        tabBuilder: (context, i){
          return Center(child: Text('Hello, world!'),);
        },
      );
  }
}