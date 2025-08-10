import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';
import 'dart:io' show Platform;

import '../services/data_repository.dart';
import 'search_page.dart';
import 'auth_page.dart';

class ProfileFilterPage extends StatefulWidget {
  final bool showSymbol;
  final bool showName;
  final bool showPrice;
  final bool showPercentChange;
  final bool showAbsoluteChange;
  final bool showVolume;
  final bool showOpeningPrice;
  final bool showDailyHighLow;
  final String separator;

  const ProfileFilterPage({
    Key? key,
    required this.showSymbol,
    required this.showName,
    required this.showPrice,
    required this.showPercentChange,
    required this.showAbsoluteChange,
    required this.showVolume,
    required this.showOpeningPrice,
    required this.showDailyHighLow,
    required this.separator,
  }) : super(key: key);

  @override
  State<ProfileFilterPage> createState() => _ProfileFilterPageState();
}

class _ProfileFilterPageState extends State<ProfileFilterPage> {
  late bool _showSymbol;
  late bool _showName;
  late bool _showPrice;
  late bool _showPercentChange;
  late bool _showAbsoluteChange;
  late bool _showVolume;
  late bool _showOpeningPrice;
  late bool _showDailyHighLow;
  late String _separator;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _newPasswordController = TextEditingController();
  bool _isLoadingPrefs = false;

  // We'll track darkMode locally
  bool _tempDarkMode = false;
  // Track the actual app dark mode state
  late bool _actualDarkMode;

  // PiP mode settings
  double _pipAnimationSpeed = 1.0; // 1x, 2x, 4x
  double _pipFontSize = 1.0; // 0.8x, 1.0x, 1.2x
  
  // Animation mode settings
  double _animationModeSpeed = 1.0; // 1x, 2x, 4x
  double _animationModeFontSize = 1.0; // 0.8x, 1.0x, 1.2x

  @override
  void initState() {
    super.initState();
    _showSymbol         = widget.showSymbol;
    _showName           = widget.showName;
    _showPrice          = widget.showPrice;
    _showPercentChange  = widget.showPercentChange;
    _showAbsoluteChange = widget.showAbsoluteChange;
    _showVolume         = widget.showVolume;
    _showOpeningPrice   = widget.showOpeningPrice;
    _showDailyHighLow   = widget.showDailyHighLow;
    _separator          = widget.separator;

    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    _actualDarkMode = dataRepo.darkMode;
    _tempDarkMode = _actualDarkMode;  // Initialize temp with actual

    _loadUserFilterPreferences();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _loadUserFilterPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isLoadingPrefs = true);
    try {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnap.exists) {
        final data = docSnap.data();
        if (data != null && data['filterPreferences'] is Map) {
          final prefs = data['filterPreferences'] as Map<String, dynamic>;
          setState(() {
            _showSymbol         = prefs['showSymbol']         ?? _showSymbol;
            _showName           = prefs['showName']           ?? _showName;
            _showPrice          = prefs['showPrice']          ?? _showPrice;
            _showPercentChange  = prefs['showPercentChange']  ?? _showPercentChange;
            _showAbsoluteChange = prefs['showAbsoluteChange'] ?? _showAbsoluteChange;
            _showVolume         = prefs['showVolume']         ?? _showVolume;
            _showOpeningPrice   = prefs['showOpeningPrice']   ?? _showOpeningPrice;
            _showDailyHighLow   = prefs['showDailyHighLow']   ?? _showDailyHighLow;
            _separator          = prefs['separator']          ?? _separator;

            // PiP mode settings
            _pipAnimationSpeed     = prefs['pipAnimationSpeed']     ?? _pipAnimationSpeed;
            _pipFontSize           = prefs['pipFontSize']           ?? _pipFontSize;
            
            // Animation mode settings
            _animationModeSpeed     = prefs['animationModeSpeed']     ?? _animationModeSpeed;
            _animationModeFontSize  = prefs['animationModeFontSize']  ?? _animationModeFontSize;

            // Dark mode
            if (prefs.containsKey('darkMode')) {
              _tempDarkMode = prefs['darkMode'];
              final dataRepo = Provider.of<DataRepository>(context, listen: false);
              dataRepo.darkMode = _tempDarkMode; // immediate apply
            }
          });
        }
      }
    } catch (_) {
      // handle error if needed
    } finally {
      setState(() => _isLoadingPrefs = false);
    }
  }

  /// We call this whenever the user toggles or at final save
  Future<void> _saveUserFilterPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'filterPreferences': {
          'showSymbol':         _showSymbol,
          'showName':           _showName,
          'showPrice':          _showPrice,
          'showPercentChange':  _showPercentChange,
          'showAbsoluteChange': _showAbsoluteChange,
          'showVolume':         _showVolume,
          'showOpeningPrice':   _showOpeningPrice,
          'showDailyHighLow':   _showDailyHighLow,
          'separator':          _separator,
          'pipAnimationSpeed':     _pipAnimationSpeed,
          'pipFontSize':           _pipFontSize,
          'animationModeSpeed':    _animationModeSpeed,
          'animationModeFontSize': _animationModeFontSize,
          'darkMode':           _tempDarkMode,
        }
      }, SetOptions(merge: true));
    } catch (_) {
      // handle error if needed
    }
  }

  Future<void> _changePassword() async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await user.updatePassword(_newPasswordController.text);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully! Please log out and log back in.')),
        );
        _newPasswordController.clear();
      } catch (e) {
        String errorMessage = 'Error changing password. Please try again.';
        
        if (e is FirebaseAuthException) {
          switch (e.code) {
            case 'requires-recent-login':
              errorMessage = 'Please log out and log back in to change your password.';
              break;
            case 'weak-password':
              errorMessage = 'Password is too weak. Please use a stronger password.';
              break;
            case 'network-request-failed':
              errorMessage = 'Network error. Please check your connection and try again.';
              break;
            default:
              errorMessage = 'Error changing password. Please try again.';
          }
        } else {
          // Handle non-Firebase exceptions
          if (e.toString().contains('network') || e.toString().contains('connection')) {
            errorMessage = 'Network error. Please check your connection and try again.';
          } else if (e.toString().contains('timeout')) {
            errorMessage = 'Request timed out. Please try again.';
          } else {
            errorMessage = 'Unexpected error occurred. Please try again.';
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    }
  }

  /// "Save & Back"
  Future<void> _saveAndPop() async {
    await _saveUserFilterPreferences();
    if (mounted) {
      final dataRepo = Provider.of<DataRepository>(context, listen: false);
      dataRepo.darkMode = _tempDarkMode;  // Only apply dark mode when saving
      
      // Return all user-chosen preferences (including darkMode!)
      Navigator.pop(context, {
        'showSymbol':         _showSymbol,
        'showName':           _showName,
        'showPrice':          _showPrice,
        'showPercentChange':  _showPercentChange,
        'showAbsoluteChange': _showAbsoluteChange,
        'showVolume':         _showVolume,
        'showOpeningPrice':   _showOpeningPrice,
        'showDailyHighLow':   _showDailyHighLow,
        'separator':          _separator,
        'pipAnimationSpeed':     _pipAnimationSpeed,
        'pipFontSize':           _pipFontSize,
        'animationModeSpeed':    _animationModeSpeed,
        'animationModeFontSize': _animationModeFontSize,
        'darkMode':           _tempDarkMode,
      });
    }
  }

  /// Logout method: sign out and navigate to AuthPage
  Future<void> _logout() async {
    // First notify the DataRepository to clean up if needed
    final dataRepo = Provider.of<DataRepository>(context, listen: false);
    dataRepo.cleanup(); // Add this method to DataRepository if not exists

    // Sign out
    await _auth.signOut();

    if (mounted) {
      // Use pushAndRemoveUntil to clear the entire navigation stack
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AuthPage()),
        (route) => false,
      );
    }
  }

  /// Open account deletion form
  Future<void> _openAccountDeletionForm() async {
    const url = 'https://docs.google.com/forms/d/e/1FAIpQLSfGoCPxcFqlWEp9iTVKoR3H99JLLhD6rAz23_qqqMjGa-IDMA/viewform?usp=header';
    
    try {
      final uri = Uri.parse(url);
      
      // Try to launch URL with external application first
      if (await canLaunchUrl(uri)) {
        final result = await launchUrl(
          uri, 
          mode: LaunchMode.externalApplication,
        );
        
        if (!result) {
          // If external application fails, try in-app browser
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        }
      } else {
        // If canLaunchUrl returns false, try launching anyway
        try {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication,
          );
        } catch (e) {
          // Final fallback - try in-app browser
          await launchUrl(
            uri,
            mode: LaunchMode.inAppWebView,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening form: $e'),
            action: SnackBarAction(
              label: 'Copy Link',
              onPressed: () {
                // Copy the URL to clipboard as fallback
                Clipboard.setData(const ClipboardData(
                  text: 'https://docs.google.com/forms/d/e/1FAIpQLSfGoCPxcFqlWEp9iTVKoR3H99JLLhD6rAz23_qqqMjGa-IDMA/viewform?usp=header',
                ));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied to clipboard')),
                );
              },
            ),
          ),
        );
      }
    }
  }

  /// Share app functionality
  void _shareApp() async {
    final String appName = 'Stock Stream App';
    final String appDescription = 'Real-time stock ticker with customizable watchlist & in-app market insights. Stay ahead of the market with our real-time, customizable stock ticker app.';
    
    String shareText = '$appName\n\n$appDescription\n\n';
    
    // Add platform-specific app store links
    if (Platform.isIOS) {
      shareText += 'Download on App Store: https://apps.apple.com/app/stock-stream-app/id6747456894';
    } else if (Platform.isAndroid) {
      shareText += 'Download on Google Play: https://play.google.com/store/apps/details?id=com.clash.stocktok';
    } else {
      // Fallback for web or other platforms
      shareText += 'Download on App Store: https://apps.apple.com/app/stock-stream-app/id6747456894\n';
      shareText += 'Download on Google Play: https://play.google.com/store/apps/details?id=com.clash.stocktok';
    }
    
    // Copy to clipboard and show success message
    await Clipboard.setData(ClipboardData(text: shareText));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('App link copied to clipboard! Share it with your friends.'),
          action: SnackBarAction(
            label: 'Share',
            onPressed: () async {
              // Try to open the native share dialog
              final Uri url = Uri.parse(
                Platform.isIOS 
                  ? 'https://apps.apple.com/app/stock-stream-app/id6747456894'
                  : 'https://play.google.com/store/apps/details?id=com.clash.stocktok'
              );
              
              if (await canLaunchUrl(url)) {
                await launchUrl(url, mode: LaunchMode.externalApplication);
              }
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final minHorizontalPadding = 16.0;
        final maxHorizontalPadding = 64.0;
        final horizontalPadding = (width * 0.04).clamp(minHorizontalPadding, maxHorizontalPadding);
        final minButtonHeight = 48.0;
        final maxButtonHeight = 70.0;
        final buttonHeight = (height * 0.07).clamp(minButtonHeight, maxButtonHeight);
        final minFontSize = 14.0;
        final maxFontSize = 22.0;
        final buttonFontSize = (width * 0.042).clamp(minFontSize, maxFontSize);
        final contentPadding = EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: height * 0.02);
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          appBar: AppBar(
            title: const Text('Profile & Filters'),
          ),
          body: _isLoadingPrefs
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: contentPadding,
                  child: Column(
                    children: [
                      // User Profile
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'User Profile',
                                    style: TextStyle(
                                      fontSize: width * 0.045,
                                      fontWeight: FontWeight.bold,
                                      color:
                                      isDark ? Colors.white : Colors.black,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.exit_to_app),
                                    tooltip: 'Logout',
                                    onPressed: _logout,
                                  )
                                ],
                              ),
                              const Divider(),
                              Text(
                                'Logged in as: ${_auth.currentUser?.email ?? 'No email'}',
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                  color: isDark ? Colors.white70 : Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: height * 0.01),
                              TextField(
                                controller: _newPasswordController,
                                decoration: InputDecoration(
                                  labelText: 'New Password',
                                  labelStyle: TextStyle(fontSize: width * 0.04),
                                  border: const OutlineInputBorder(),
                                ),
                                obscureText: true,
                              ),
                              SizedBox(height: height * 0.01),
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: ElevatedButton(
                                  onPressed: _changePassword,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E9712), // brand color
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: Text(
                                    'Change Password',
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Display Filters
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Column(
                            children: [
                              Text(
                                'Display Filters',
                                style: TextStyle(
                                  fontSize: width * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Divider(),
                              _buildSwitchTile('Show Symbol', _showSymbol,
                                      (v) => setState(() => _showSymbol = v)),
                              _buildSwitchTile('Show Name', _showName,
                                      (v) => setState(() => _showName = v)),
                              _buildSwitchTile('Show Current Price', _showPrice,
                                      (v) => setState(() => _showPrice = v)),
                              _buildSwitchTile('Show % Change', _showPercentChange,
                                      (v) => setState(() => _showPercentChange = v)),
                              _buildSwitchTile(
                                  'Show Price Change (Absolute)',
                                  _showAbsoluteChange,
                                      (v) => setState(() => _showAbsoluteChange = v)),
                              _buildSwitchTile('Show Volume', _showVolume,
                                      (v) => setState(() => _showVolume = v)),
                              _buildSwitchTile(
                                  'Show Opening Price',
                                  _showOpeningPrice,
                                      (v) => setState(() => _showOpeningPrice = v)),
                              _buildSwitchTile(
                                  'Show Daily High/Low',
                                  _showDailyHighLow,
                                      (v) => setState(() => _showDailyHighLow = v)),
                              const Divider(),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Separator Style',
                                  style: TextStyle(
                                    fontSize: width * 0.04,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(height: height * 0.01),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _buildSeparatorChip(' .... '),
                                  _buildSeparatorChip(', '),
                                  _buildSeparatorChip(' | '),
                                  _buildSeparatorChip(' – '),
                                  _buildSeparatorChip(' / '),
                                  _buildSeparatorChip(' • '),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // PiP Mode Settings
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(
                          vertical: height * 0.01,
                          horizontal: width * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark 
                            ? Border.all(color: Colors.grey[700]!, width: 1)
                            : Border.all(color: Colors.grey[200]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PiP Mode Settings',
                                style: TextStyle(
                                  fontSize: (width * 0.045).clamp(16.0, 22.0),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.008),
                              Text(
                                'Picture-in-Picture mode: Small floating window overlay',
                                style: TextStyle(
                                  fontSize: (width * 0.035).clamp(12.0, 16.0),
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              SizedBox(height: height * 0.015),
                              Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                              SizedBox(height: height * 0.015),
                              
                              // PiP Animation Speed
                              Text(
                                'Animation Speed',
                                style: TextStyle(
                                  fontSize: (width * 0.04).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.012),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = width >= 600;
                                  final spacing = isTablet ? 12.0 : 8.0;
                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      _buildPipSpeedChip('1x', 1.0, width, isTablet),
                                      _buildPipSpeedChip('2x', 2.0, width, isTablet),
                                      _buildPipSpeedChip('4x', 4.0, width, isTablet),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: height * 0.025),
                              
                              // PiP Font Size
                              Text(
                                'Font Size',
                                style: TextStyle(
                                  fontSize: (width * 0.04).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.012),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = width >= 600;
                                  final spacing = isTablet ? 12.0 : 8.0;
                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      _buildPipFontSizeChip('1x', 1.0, width, isTablet),
                                      _buildPipFontSizeChip('2x', 2.0, width, isTablet),
                                      _buildPipFontSizeChip('4x', 4.0, width, isTablet),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Animation Mode Settings
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.symmetric(
                          vertical: height * 0.01,
                          horizontal: width * 0.02,
                        ),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: isDark 
                            ? Border.all(color: Colors.grey[700]!, width: 1)
                            : Border.all(color: Colors.grey[200]!, width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black12,
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Animation Mode Settings',
                                style: TextStyle(
                                  fontSize: (width * 0.045).clamp(16.0, 22.0),
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.008),
                              Text(
                                'Full-screen scrolling ticker animation mode',
                                style: TextStyle(
                                  fontSize: (width * 0.035).clamp(12.0, 16.0),
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              SizedBox(height: height * 0.015),
                              Divider(color: isDark ? Colors.grey[700] : Colors.grey[300]),
                              SizedBox(height: height * 0.015),
                              
                              // Animation Mode Speed
                              Text(
                                'Animation Speed',
                                style: TextStyle(
                                  fontSize: (width * 0.04).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.012),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = width >= 600;
                                  final spacing = isTablet ? 12.0 : 8.0;
                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      _buildAnimationSpeedChip('1x', 1.0, width, isTablet),
                                      _buildAnimationSpeedChip('2x', 2.0, width, isTablet),
                                      _buildAnimationSpeedChip('4x', 4.0, width, isTablet),
                                    ],
                                  );
                                },
                              ),
                              SizedBox(height: height * 0.025),
                              
                              // Animation Mode Font Size
                              Text(
                                'Font Size',
                                style: TextStyle(
                                  fontSize: (width * 0.04).clamp(14.0, 18.0),
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              SizedBox(height: height * 0.012),
                              LayoutBuilder(
                                builder: (context, constraints) {
                                  final isTablet = width >= 600;
                                  final spacing = isTablet ? 12.0 : 8.0;
                                  return Wrap(
                                    spacing: spacing,
                                    runSpacing: spacing,
                                    alignment: WrapAlignment.start,
                                    children: [
                                      _buildAnimationFontSizeChip('1x', 1.0, width, isTablet),
                                      _buildAnimationFontSizeChip('2x', 2.0, width, isTablet),
                                      _buildAnimationFontSizeChip('4x', 4.0, width, isTablet),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Dark Mode immediate
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Row(
                            children: [
                              Text(
                                'Dark Mode',
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              Switch(
                                value: _tempDarkMode,
                                onChanged: (val) async {
                                  setState(() => _tempDarkMode = val);
                                  // Don't apply to dataRepo immediately anymore
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      SizedBox(height: height * 0.03),
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Row(
                            children: [
                              Text(
                                'Click to refer our app',
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: Icon(
                                  Icons.share,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                onPressed: _shareApp,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Account Deletion Section
                      Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[900] : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(width * 0.04),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Account Management',
                                style: TextStyle(
                                  fontSize: width * 0.045,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                              ),
                              const Divider(),
                              Text(
                                'Request account deletion',
                                style: TextStyle(
                                  fontSize: width * 0.04,
                                  color: isDark ? Colors.white70 : Colors.grey[800],
                                ),
                              ),
                              SizedBox(height: height * 0.01),
                              SizedBox(
                                width: double.infinity,
                                height: buttonHeight,
                                child: ElevatedButton.icon(
                                  onPressed: _openAccountDeletionForm,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red[600],
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  icon: const Icon(Icons.delete_forever),
                                  label: Text(
                                    'Delete Account',
                                    style: TextStyle(
                                      fontSize: buttonFontSize,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Add Stocks
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                const SearchPage(forceSelection: false),
                              ),
                            );
                            // After search, we pop from the filters page
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E9712),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.add),
                          label: Text(
                            'Add Stocks to Watchlist',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: height * 0.03),

                      // Save & Back
                      SizedBox(
                        width: double.infinity,
                        height: buttonHeight,
                        child: OutlinedButton(
                          onPressed: _saveAndPop,
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey.shade200
                                  : Colors.grey.shade800,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            'Save & Back',
                            style: TextStyle(
                              fontSize: buttonFontSize,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return SwitchListTile(
      title: Text(
        title,
        style: TextStyle(
          fontSize: width * 0.04,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
      value: value,
      onChanged: (val) {
        setState(() => onChanged(val));
      },
      dense: isLandscape, // More compact in landscape mode
    );
  }

  Widget _buildSeparatorChip(String sepValue) {
    final isSelected = _separator == sepValue;
    return ChoiceChip(
      label: Text(
        sepValue.trim(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      selected: isSelected,
      onSelected: (_) {
        setState(() => _separator = sepValue);
      },
    );
  }

  // PiP Mode Helper Methods
  Widget _buildPipSpeedChip(String label, double speedValue, double width, bool isTablet) {
    final isSelected = _pipAnimationSpeed == speedValue;
    final chipFontSize = (width * 0.035).clamp(12.0, 16.0);
    final minChipWidth = isTablet ? 80.0 : 60.0;
    final chipPadding = isTablet ? EdgeInsets.symmetric(horizontal: 20, vertical: 12) : EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    
    return Container(
      constraints: BoxConstraints(minWidth: minChipWidth),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: chipFontSize,
            color: isSelected ? Colors.white : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _pipAnimationSpeed = speedValue);
        },
        padding: chipPadding,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: isSelected ? 4.0 : 1.0,
        shadowColor: Colors.black26,
      ),
    );
  }

  Widget _buildPipFontSizeChip(String label, double fontSizeValue, double width, bool isTablet) {
    final isSelected = _pipFontSize == fontSizeValue;
    final chipFontSize = (width * 0.035).clamp(12.0, 16.0);
    final minChipWidth = isTablet ? 80.0 : 60.0;
    final chipPadding = isTablet ? EdgeInsets.symmetric(horizontal: 20, vertical: 12) : EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    
    return Container(
      constraints: BoxConstraints(minWidth: minChipWidth),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: chipFontSize,
            color: isSelected ? Colors.white : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _pipFontSize = fontSizeValue);
        },
        padding: chipPadding,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: isSelected ? 4.0 : 1.0,
        shadowColor: Colors.black26,
      ),
    );
  }

  // Animation Mode Helper Methods
  Widget _buildAnimationSpeedChip(String label, double speedValue, double width, bool isTablet) {
    final isSelected = _animationModeSpeed == speedValue;
    final chipFontSize = (width * 0.035).clamp(12.0, 16.0);
    final minChipWidth = isTablet ? 80.0 : 60.0;
    final chipPadding = isTablet ? EdgeInsets.symmetric(horizontal: 20, vertical: 12) : EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    
    return Container(
      constraints: BoxConstraints(minWidth: minChipWidth),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: chipFontSize,
            color: isSelected ? Colors.white : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _animationModeSpeed = speedValue);
        },
        padding: chipPadding,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: isSelected ? 4.0 : 1.0,
        shadowColor: Colors.black26,
      ),
    );
  }

  Widget _buildAnimationFontSizeChip(String label, double fontSizeValue, double width, bool isTablet) {
    final isSelected = _animationModeFontSize == fontSizeValue;
    final chipFontSize = (width * 0.035).clamp(12.0, 16.0);
    final minChipWidth = isTablet ? 80.0 : 60.0;
    final chipPadding = isTablet ? EdgeInsets.symmetric(horizontal: 20, vertical: 12) : EdgeInsets.symmetric(horizontal: 16, vertical: 10);
    
    return Container(
      constraints: BoxConstraints(minWidth: minChipWidth),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: chipFontSize,
            color: isSelected ? Colors.white : null,
          ),
        ),
        selected: isSelected,
        onSelected: (_) {
          setState(() => _animationModeFontSize = fontSizeValue);
        },
        padding: chipPadding,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        elevation: isSelected ? 4.0 : 1.0,
        shadowColor: Colors.black26,
      ),
    );
  }
}
