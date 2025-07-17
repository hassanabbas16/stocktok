import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/rendering.dart';

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
          const SnackBar(content: Text('Password changed successfully!')),
        );
        _newPasswordController.clear();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error changing password: $e')),
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
                                onPressed: () {
                                  // Placeholder for refer functionality
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Refer functionality coming soon!')),
                                  );
                                },
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
}
