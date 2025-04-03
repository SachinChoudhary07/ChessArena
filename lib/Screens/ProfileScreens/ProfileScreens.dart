import 'package:chess_cash/Constant/app_constant.dart';
import 'package:chess_cash/Constant/color_resources.dart';
import 'package:chess_cash/Constant/ui_helper.dart';
import 'package:chess_cash/Providers/ProfileProvider/ProfileProvider.dart';
import 'package:chess_cash/Widgets/loader.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class Profilescreens extends StatefulWidget {
  const Profilescreens({super.key});

  @override
  State<Profilescreens> createState() => _ProfilescreensState();
}

class _ProfilescreensState extends State<Profilescreens> {
  @override
  void initState() {
    super.initState();
    Provider.of<ProfileProvider>(context, listen: false).fetchUserProfile();
  }

  void _showLogoutConfirmationDialog(ProfileProvider provider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(AppConstants.confirmLogout),
          content: const Text(AppConstants.sureLogOut),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(AppConstants.cancel),
            ),
            TextButton(
              onPressed: () {
                provider.logout(context);
              },
              child: const Text(
                AppConstants.logout,
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(AppConstants.profile),
        backgroundColor: ColorResources.primaryColor,
      ),
      body: Consumer<ProfileProvider>(
        builder: (context, profileProvider, child) {
          if (profileProvider.isLoading) {
            return const Center(child: Loader());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 66,
                          backgroundImage: NetworkImage(
                            profileProvider.profileImageUrl ??
                                'https://encrypted-tbn0.gstatic.com/images?q=tbn:ANd9GcSSzGVa3SoC992I_CxrcuJt7Hms5yCufJo_aTAI2yTFSqs0_YTQ1SpjaCJxenSUUBFXdUg&usqp=CAU',
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: InkWell(
                            onTap: () {
                              profileProvider.updateProfileImage();
                            },
                            child: CircleAvatar(
                              radius: 15,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit,
                                  size: 15, color: ColorResources.primaryColor),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Helper.heightSizedBox(26),
                  TextField(
                    controller:
                        TextEditingController(text: profileProvider.name),
                    decoration: const InputDecoration(
                      labelText: AppConstants.userName,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Helper.heightSizedBox(8),
                  TextField(
                    controller:
                        TextEditingController(text: profileProvider.email),
                    decoration: const InputDecoration(
                      labelText: AppConstants.email,
                      border: OutlineInputBorder(),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: ColorResources.secondaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.updateProfile,
                        style: TextStyle(color: ColorResources.secondaryColor),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border:
                            Border.all(color: ColorResources.secondaryColor),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppConstants.inviteFriends,
                        style: TextStyle(color: ColorResources.secondaryColor),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () => _showLogoutConfirmationDialog(profileProvider),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        AppConstants.logout,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                  Helper.heightSizedBox(16),
                  GestureDetector(
                    onTap: () {},
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        AppConstants.deleteAccount,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
