import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileFilterPage extends StatefulWidget {
  // Current filter booleans
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

  @override
  void initState() {
    super.initState();
    _showSymbol = widget.showSymbol;
    _showName = widget.showName;
    _showPrice = widget.showPrice;
    _showPercentChange = widget.showPercentChange;
    _showAbsoluteChange = widget.showAbsoluteChange;
    _showVolume = widget.showVolume;
    _showOpeningPrice = widget.showOpeningPrice;
    _showDailyHighLow = widget.showDailyHighLow;
    _separator = widget.separator;

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
            _showSymbol        = prefs['showSymbol']        ?? _showSymbol;
            _showName          = prefs['showName']          ?? _showName;
            _showPrice         = prefs['showPrice']         ?? _showPrice;
            _showPercentChange = prefs['showPercentChange'] ?? _showPercentChange;
            _showAbsoluteChange= prefs['showAbsoluteChange']?? _showAbsoluteChange;
            _showVolume        = prefs['showVolume']        ?? _showVolume;
            _showOpeningPrice  = prefs['showOpeningPrice']  ?? _showOpeningPrice;
            _showDailyHighLow  = prefs['showDailyHighLow']  ?? _showDailyHighLow;
            _separator         = prefs['separator']         ?? _separator;
          });
        }
      }
    } catch (e) {
      // show error
    } finally {
      setState(() => _isLoadingPrefs = false);
    }
  }

  Future<void> _saveUserFilterPreferences() async {
    final user = _auth.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'filterPreferences': {
          'showSymbol':        _showSymbol,
          'showName':          _showName,
          'showPrice':         _showPrice,
          'showPercentChange': _showPercentChange,
          'showAbsoluteChange':_showAbsoluteChange,
          'showVolume':        _showVolume,
          'showOpeningPrice':  _showOpeningPrice,
          'showDailyHighLow':  _showDailyHighLow,
          'separator':         _separator,
        }
      }, SetOptions(merge: true));
    } catch (e) {
      // handle error
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

  Future<void> _saveAndPop() async {
    await _saveUserFilterPreferences();
    Navigator.pop(context, {
      'showSymbol': _showSymbol,
      'showName': _showName,
      'showPrice': _showPrice,
      'showPercentChange': _showPercentChange,
      'showAbsoluteChange': _showAbsoluteChange,
      'showVolume': _showVolume,
      'showOpeningPrice': _showOpeningPrice,
      'showDailyHighLow': _showDailyHighLow,
      'separator': _separator,
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Profile & Filters',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            if (_isLoadingPrefs)
              const LinearProgressIndicator(),

            // ========== USER PROFILE ==========
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'User Profile',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    Text('Logged in as: $email'),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _newPasswordController,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _changePassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.greenAccent,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ========== FILTERS ==========
            Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Display Filters',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Divider(),
                    _buildSwitchTile(
                      title: 'Show Symbol',
                      value: _showSymbol,
                      onChanged: (val) => setState(() => _showSymbol = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Name',
                      value: _showName,
                      onChanged: (val) => setState(() => _showName = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Current Price',
                      value: _showPrice,
                      onChanged: (val) => setState(() => _showPrice = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show % Change',
                      value: _showPercentChange,
                      onChanged: (val) => setState(() => _showPercentChange = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Price Change (Absolute)',
                      value: _showAbsoluteChange,
                      onChanged: (val) => setState(() => _showAbsoluteChange = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Volume',
                      value: _showVolume,
                      onChanged: (val) => setState(() => _showVolume = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Opening Price',
                      value: _showOpeningPrice,
                      onChanged: (val) => setState(() => _showOpeningPrice = val),
                    ),
                    _buildSwitchTile(
                      title: 'Show Daily High/Low',
                      value: _showDailyHighLow,
                      onChanged: (val) => setState(() => _showDailyHighLow = val),
                    ),
                    const Divider(),
                    const Text(
                      'Separator Style',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 120,
                      child: GridView.count(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 3,
                        children: [
                          _buildSeparatorChip(' .... '),
                          _buildSeparatorChip(', '),
                          _buildSeparatorChip(' | '),
                          _buildSeparatorChip(' – '),
                          _buildSeparatorChip(' / '),
                          _buildSeparatorChip(' • '),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),
            // ========== SAVE BUTTON ==========
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saveAndPop,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue,
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Colors.blue, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('Save & Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      title: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeColor: Colors.greenAccent,
    );
  }

  Widget _buildSeparatorChip(String sepValue) {
    return ChoiceChip(
      label: Text(
        sepValue.trim(),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      selected: _separator == sepValue,
      selectedColor: Colors.greenAccent,
      onSelected: (val) {
        setState(() {
          _separator = sepValue;
        });
      },
    );
  }
}
