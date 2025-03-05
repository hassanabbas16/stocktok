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
                  Image.asset('assets/icons/iconf.png', height: height * 0.05),
                  const SizedBox(width: 6),
                  Text.rich(
                    TextSpan(
                      children: [
                        // "Stock" color depends on theme
                        TextSpan(
                          text: 'Stock',
                          style: TextStyle(
                            fontSize: width * 0.09,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: 'Tok',
                          style: TextStyle(
                            fontSize: width * 0.09,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFE5F64A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              SizedBox(height: height * 0.05),

              // Stock Cards in Hierarchy
              SizedBox(
                height: height * 0.2,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: height * 0.05,
                      left: width * 0.15,
                      child: stockCard(
                        'AAPL',
                        '+108,68%',
                        'assets/logos/apple.png',
                        Colors.blue,
                        width * 0.18,
                        height * 0.1,
                        isDark,
                      ),
                    ),
                    Positioned(
                      top: height * 0.03,
                      right: width * 0.15,
                      child: stockCard(
                        'UNVR',
                        '+82,34%',
                        'assets/logos/uni.png',
                        Colors.orange,
                        width * 0.18,
                        height * 0.1,
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
                        width * 0.18,
                        height * 0.1,
                        isDark,
                      ),
                    ),
                    Positioned(
                      top: height * 0.11,
                      child: stockCard(
                        'BTC',
                        '+198,39%',
                        'assets/logos/bitcoin.png',
                        Colors.green,
                        width * 0.18,
                        height * 0.1,
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
                    backgroundColor: const Color(0xFFE5F64A),
                    foregroundColor: Colors.black,
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
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        // Keep the card white in light mode, or slightly darker in dark mode if desired
        color: isDark ? Colors.grey[900] : Colors.white,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Image.asset(
            iconPath,
            height: cardHeight * 0.35,
            color: shouldBeWhite ? Colors.white : null,
          ),
          const SizedBox(height: 4),
          Text(
            ticker,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Text(
            change,
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ),
    );
  }
}
