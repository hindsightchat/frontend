import 'package:flutter/material.dart';
import 'package:hindsightchat/components/Colours.dart';
import 'package:hindsightchat/providers/DataProvider.dart';
import 'package:hindsightchat/types/models.dart';
import 'package:provider/provider.dart';

class UserSidebar extends StatefulWidget {
  final String otherUserId;
  final String participantName;
  const UserSidebar({
    super.key,
    required this.otherUserId,
    required this.participantName,
  });

  @override
  State<UserSidebar> createState() => _UserSidebarState();
}

class _UserSidebarState extends State<UserSidebar> {
  @override
  Widget build(BuildContext context) {
    DataProvider dataProvider = Provider.of<DataProvider>(
      context,
      listen: true,
    );

    final user = dataProvider.getUser(widget.otherUserId);

    return Container(
      width: 300,
      decoration: BoxDecoration(color: UserProfileSideBarColor),
      child: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: MessageBorderColor, width: 1),
              ),
              color: MessageBackgroundColor,
            ),
            alignment: Alignment.centerLeft,
            child: SizedBox.shrink(),
          ),
          // panel content
          Expanded(
            child: Container(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // banner fill width of panel and height of 100px, with rounded corners
                      Container(
                        height: 100,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: MessageBackgroundColor,
                        ),
                        // image take entire container but maintain aspect ratio and be centered
                        // as base64
                        child: Image.network(
                          "https://i.redd.it/i9zw9k4hoqj51.jpg",
                          fit: BoxFit.cover,
                        ),
                      ),

                      // profile picture 80x80px, circular, with border of 4px in UserProfileSideBarColor, overlapping banner and centered horizontally
                      Positioned(
                        top: 60,
                        left: 20,
                        child: Stack(
                          children: [
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(40),
                                border: Border.all(
                                  color: UserProfileSideBarColor,
                                  width: 4,
                                ),
                                color: UserProfileSideBarColor, // .
                                image: const DecorationImage(
                                  image: NetworkImage(
                                    "https://github.com/DwifteJB.png",
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: MainAccessColor(
                                    user?.presence?.status ?? 'offline',
                                  ),
                                  borderRadius: BorderRadius.circular(30),
                                  border: Border.all(
                                    color: UserProfileSideBarColor,
                                    width: 4,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 60),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.participantName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            fontFamily: "Inter",
                          ),
                        ),
                        SizedBox(height: 10),
                        Container(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 12, bottom: 12),
                            child: Text(
                              'product, web & app designer  ·  vitonkls.com ',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: "Inter",
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),

                        if (user != null &&
                            user.presence != null &&
                            user.presence!.activity != null)
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: MessageBackgroundColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            padding: EdgeInsets.all(12),
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: 12,
                                bottom: 12,
                              ),
                              child: Text(
                                '${user.presence!.activity!.details.isNotEmpty ? user.presence!.activity!.details : user.presence!.activity!.state} on ${user.presence!.activity!.AppName}',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontFamily: "Inter",
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
