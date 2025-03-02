import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'search_page.dart';

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
            _showSymbol         = prefs['showSymbol']        ?? _showSymbol;
            _showName           = prefs['showName']          ?? _showName;
            _showPrice          = prefs['showPrice']         ?? _showPrice;
            _showPercentChange  = prefs['showPercentChange'] ?? _showPercentChange;
            _showAbsoluteChange = prefs['showAbsoluteChange']?? _showAbsoluteChange;
            _showVolume         = prefs['showVolume']        ?? _showVolume;
            _showOpeningPrice   = prefs['showOpeningPrice']  ?? _showOpeningPrice;
            _showDailyHighLow   = prefs['showDailyHighLow']  ?? _showDailyHighLow;
            _separator          = prefs['separator']         ?? _separator;
          });
        }
      }
    } catch (_) {
      // handle error
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
          'showSymbol':         _showSymbol,
          'showName':           _showName,
          'showPrice':          _showPrice,
          'showPercentChange':  _showPercentChange,
          'showAbsoluteChange': _showAbsoluteChange,
          'showVolume':         _showVolume,
          'showOpeningPrice':   _showOpeningPrice,
          'showDailyHighLow':   _showDailyHighLow,
          'separator':          _separator,
        }
      }, SetOptions(merge: true));
    } catch (_) {}
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
    if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    final email = _auth.currentUser?.email ?? 'No email';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Filters'),
      ),
      body: _isLoadingPrefs
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          children: [
            // User Profile
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('User Profile', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
                        child: const Text('Change Password'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Display Filters
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text('Display Filters', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Divider(),
                    _buildSwitchTile('Show Symbol', _showSymbol, (v) => setState(() => _showSymbol = v)),
                    _buildSwitchTile('Show Name', _showName, (v) => setState(() => _showName = v)),
                    _buildSwitchTile('Show Current Price', _showPrice, (v) => setState(() => _showPrice = v)),
                    _buildSwitchTile('Show % Change', _showPercentChange, (v) => setState(() => _showPercentChange = v)),
                    _buildSwitchTile('Show Price Change (Absolute)', _showAbsoluteChange, (v) => setState(() => _showAbsoluteChange = v)),
                    _buildSwitchTile('Show Volume', _showVolume, (v) => setState(() => _showVolume = v)),
                    _buildSwitchTile('Show Opening Price', _showOpeningPrice, (v) => setState(() => _showOpeningPrice = v)),
                    _buildSwitchTile('Show Daily High/Low', _showDailyHighLow, (v) => setState(() => _showDailyHighLow = v)),
                    const Divider(),
                    const Text('Separator Style', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
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
            const SizedBox(height: 16),

            // Add Stocks
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchPage(forceSelection: false)));
              },
              icon: const Icon(Icons.add),
              label: const Text('Add Stocks to Watchlist'),
            ),
            const SizedBox(height: 16),

            // Save & Back
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _saveAndPop,
                child: const Text('Save & Back'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(title),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSeparatorChip(String sepValue) {
    return ChoiceChip(
      label: Text(sepValue.trim()),
      selected: _separator == sepValue,
      onSelected: (_) {
        setState(() => _separator = sepValue);
      },
    );
  }
}
