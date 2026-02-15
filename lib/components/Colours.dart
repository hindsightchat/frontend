// british colours but most people are american so only the name of the file is colours lol
import 'dart:ui';

// #151517
Color DarkBackgroundColor = const Color(0xFF151517);

// #161515
Color MessageBackgroundColor = const Color(0xFF161515);

// #2D2D2D
Color MessageBorderColor = const Color(0xFF2D2D2D);

// MessageSendBox 0xFF232428
Color MessageSendBoxColor = const Color(0xFF232428);

// 0xFF767676
Color MutedTextColor = const Color(0xFF767676);

// 7B7B7B
Color SidebarSectionTextColor = const Color(0xFF7B7B7B);

// 080808
Color UserProfileSideBarColor = const Color(0xFF080808);

Color UserProfileDescriptionBGColor = const Color(0xFF3C3C3C);

Color MainAccessColor(String status) {
  switch (status) {
    case 'online':
      return const Color(0xFF3BA55C); // Green
    case 'idle':
      return const Color(0xFFFAA61A); // Yellow/Orange
    case 'dnd':
      return const Color(0xFFED4245); // Red
    default:
      return const Color(0xFF747F8D); // Gray (offline)
  }
}
