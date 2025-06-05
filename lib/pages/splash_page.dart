import 'package:flutter/material.dart';
import 'auth_page.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      // Use the theme's scaffoldBackgroundColor
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: width * 0.06),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo + App Name
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset('assets/icons/auth_logo.png', height: height * 0.05)
                ],
              ),

              SizedBox(height: height * 0.05),

              // Stock Cards in Hierarchy
              SizedBox(
                height: height * 0.25,
                width: width,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: height * 0.06,
                      left: width * 0.1,
                      child: stockCard(
                        'AAPL',
                        '+108,68%',
                        'assets/logos/apple.png',
                        Colors.blue,
                        width * 0.22,
                        height * 0.11,
                        isDark,
                      ),
                    ),
                    Positioned(
                      top: height * 0.04,
                      right: width * 0.1,
                      child: stockCard(
                        'UNVR',
                        '+82,34%',
                        'assets/logos/uni.png',
                        Colors.orange,
                        width * 0.22,
                        height * 0.11,
                        isDark,
                      ),
                    ),
                    Positioned(
                      top: 0,
                      child: stockCard(
                        'TSLA',
                        '-54,49%',
                        'assets/logos/tesla.png',
                        Colors.red,
                        width * 0.22,
                        height * 0.11,
                        isDark,
                      ),
                    ),
                    Positioned(
                      top: height * 0.12,
                      child: stockCard(
                        'BTC',
                        '+198,39%',
                        'assets/logos/bitcoin.png',
                        Colors.green,
                        width * 0.22,
                        height * 0.11,
                        isDark,
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: height * 0.05),

              // Main Heading
              Text(
                'Track Stocks In Real-Time',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.06,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),

              const SizedBox(height: 4),

              // Subheading
              Text(
                'Get instant price updates & insights at a glance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: width * 0.035,
                  color: isDark ? const Color(0xFFC2C2C2) : Colors.grey[600],
                ),
              ),

              SizedBox(height: height * 0.05),

              // Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (context) => const AuthPage()),
                    );
                  },
                  // Only change the background color to #E5F64A; keep the rest
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E9712),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text(
                    "Let's Get Started",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget stockCard(
      String ticker,
      String change,
      String iconPath,
      Color color,
      double cardWidth,
      double cardHeight,
      bool isDark,
      ) {
    // Use white color filter for Apple & Tesla if dark mode
    final bool shouldBeWhite = isDark && (iconPath.contains('apple') || iconPath.contains('tesla'));

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.all(cardHeight * 0.08),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
        borderRadius: BorderRadius.circular(cardHeight * 0.15),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            iconPath,
            height: cardHeight * 0.35,
            color: shouldBeWhite ? Colors.white : null,
          ),
          SizedBox(height: cardHeight * 0.04),
          Text(
            ticker,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: cardHeight * 0.11,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            change,
            style: TextStyle(
              fontSize: cardHeight * 0.11,
              color: color
            ),
          ),
        ],
      ),
    );
  }
}
