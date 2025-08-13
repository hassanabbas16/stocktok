class StockSymbolMapping {
  // Comprehensive mapping of company names to stock symbols
  // This includes major companies, popular stocks, and common search terms
  static const Map<String, String> _companyToSymbol = {
    // Major Tech Companies
    'apple': 'AAPL',
    'apple inc': 'AAPL',
    'microsoft': 'MSFT',
    'microsoft corporation': 'MSFT',
    'google': 'GOOGL',
    'alphabet': 'GOOGL',
    'alphabet inc': 'GOOGL',
    'amazon': 'AMZN',
    'amazon.com': 'AMZN',
    'amazon com': 'AMZN',
    'meta': 'META',
    'facebook': 'META',
    'meta platforms': 'META',
    'tesla': 'TSLA',
    'tesla inc': 'TSLA',
    'tesla motors': 'TSLA',
    'netflix': 'NFLX',
    'netflix inc': 'NFLX',
    'nvidia': 'NVDA',
    'nvidia corporation': 'NVDA',
    'intel': 'INTC',
    'intel corporation': 'INTC',
    'amd': 'AMD',
    'advanced micro devices': 'AMD',
    'oracle': 'ORCL',
    'oracle corporation': 'ORCL',
    'salesforce': 'CRM',
    'adobe': 'ADBE',
    'adobe inc': 'ADBE',
    'cisco': 'CSCO',
    'cisco systems': 'CSCO',
    'ibm': 'IBM',
    'international business machines': 'IBM',
    'paypal': 'PYPL',
    'paypal holdings': 'PYPL',
    'uber': 'UBER',
    'uber technologies': 'UBER',
    'lyft': 'LYFT',
    'lyft inc': 'LYFT',
    'zoom': 'ZM',
    'zoom video': 'ZM',
    'slack': 'WORK',
    'twitter': 'TWTR',
    'snapchat': 'SNAP',
    'snap': 'SNAP',
    'snap inc': 'SNAP',
    'pinterest': 'PINS',
    'pinterest inc': 'PINS',
    'linkedin': 'LNKD',
    'spotify': 'SPOT',
    'spotify technology': 'SPOT',
    'airbnb': 'ABNB',
    'airbnb inc': 'ABNB',
    'square': 'SQ',
    'block': 'SQ',
    'block inc': 'SQ',
    'shopify': 'SHOP',
    'shopify inc': 'SHOP',
    'palantir': 'PLTR',
    'palantir technologies': 'PLTR',
    'snowflake': 'SNOW',
    'snowflake inc': 'SNOW',
    'crowdstrike': 'CRWD',
    'crowdstrike holdings': 'CRWD',
    'servicenow': 'NOW',
    'servicenow inc': 'NOW',
    'datadog': 'DDOG',
    'datadog inc': 'DDOG',
    'okta': 'OKTA',
    'okta inc': 'OKTA',
    'docusign': 'DOCU',
    'docusign inc': 'DOCU',
    'dropbox': 'DBX',
    'dropbox inc': 'DBX',
    
    // Retail & Consumer
    'walmart': 'WMT',
    'walmart inc': 'WMT',
    'wal mart': 'WMT',
    'target': 'TGT',
    'target corporation': 'TGT',
    'costco': 'COST',
    'costco wholesale': 'COST',
    'home depot': 'HD',
    'the home depot': 'HD',
    'lowes': 'LOW',
    'lowe\'s': 'LOW',
    'lowe\'s companies': 'LOW',
    'starbucks': 'SBUX',
    'starbucks corporation': 'SBUX',
    'mcdonalds': 'MCD',
    'mcdonald\'s': 'MCD',
    'mcdonald\'s corporation': 'MCD',
    'coca cola': 'KO',
    'coca-cola': 'KO',
    'the coca-cola company': 'KO',
    'pepsi': 'PEP',
    'pepsico': 'PEP',
    'pepsico inc': 'PEP',
    'nike': 'NKE',
    'nike inc': 'NKE',
    'adidas': 'ADDYY',
    'under armour': 'UAA',
    'gap': 'GPS',
    'gap inc': 'GPS',
    'tjx': 'TJX',
    'tjx companies': 'TJX',
    'ross stores': 'ROST',
    'ross dress for less': 'ROST',
    'best buy': 'BBY',
    'best buy co': 'BBY',
    
    // Financial Services
    'jpmorgan': 'JPM',
    'jp morgan': 'JPM',
    'jpmorgan chase': 'JPM',
    'bank of america': 'BAC',
    'wells fargo': 'WFC',
    'citigroup': 'C',
    'citi': 'C',
    'goldman sachs': 'GS',
    'goldman sachs group': 'GS',
    'morgan stanley': 'MS',
    'american express': 'AXP',
    'amex': 'AXP',
    'visa': 'V',
    'visa inc': 'V',
    'mastercard': 'MA',
    'mastercard incorporated': 'MA',
    'berkshire hathaway': 'BRK.B',
    'berkshire': 'BRK.B',
    'warren buffett': 'BRK.B',
    'blackrock': 'BLK',
    'blackrock inc': 'BLK',
    'charles schwab': 'SCHW',
    'schwab': 'SCHW',
    'fidelity': 'FIS',
    'capital one': 'COF',
    'capital one financial': 'COF',
    'discover': 'DIS',
    'discover financial': 'DIS',
    
    // Healthcare & Pharmaceuticals
    'johnson & johnson': 'JNJ',
    'johnson and johnson': 'JNJ',
    'jnj': 'JNJ',
    'pfizer': 'PFE',
    'pfizer inc': 'PFE',
    'moderna': 'MRNA',
    'moderna inc': 'MRNA',
    'abbott': 'ABT',
    'abbott laboratories': 'ABT',
    'merck': 'MRK',
    'merck & co': 'MRK',
    'eli lilly': 'LLY',
    'lilly': 'LLY',
    'bristol myers squibb': 'BMY',
    'bristol-myers squibb': 'BMY',
    'astrazeneca': 'AZN',
    'novartis': 'NVS',
    'roche': 'RHHBY',
    'gilead': 'GILD',
    'gilead sciences': 'GILD',
    'biogen': 'BIIB',
    'biogen inc': 'BIIB',
    'regeneron': 'REGN',
    'regeneron pharmaceuticals': 'REGN',
    'vertex': 'VRTX',
    'vertex pharmaceuticals': 'VRTX',
    'amgen': 'AMGN',
    'amgen inc': 'AMGN',
    'medtronic': 'MDT',
    'medtronic plc': 'MDT',
    'thermo fisher': 'TMO',
    'thermo fisher scientific': 'TMO',
    'danaher': 'DHR',
    'danaher corporation': 'DHR',
    'intuitive surgical': 'ISRG',
    'unitedhealth': 'UNH',
    'united health': 'UNH',
    'unitedhealth group': 'UNH',
    'anthem': 'ANTM',
    'cigna': 'CI',
    'cigna corporation': 'CI',
    'humana': 'HUM',
    'humana inc': 'HUM',
    'cvs': 'CVS',
    'cvs health': 'CVS',
    'walgreens': 'WBA',
    'walgreens boots alliance': 'WBA',
    
    // Energy & Utilities
    'exxon': 'XOM',
    'exxon mobil': 'XOM',
    'exxonmobil': 'XOM',
    'chevron': 'CVX',
    'chevron corporation': 'CVX',
    'conocophillips': 'COP',
    'shell': 'SHEL',
    'royal dutch shell': 'SHEL',
    'bp': 'BP',
    'british petroleum': 'BP',
    'total': 'TTE',
    'totalenergies': 'TTE',
    'enbridge': 'ENB',
    'kinder morgan': 'KMI',
    'enterprise products': 'EPD',
    'nextera': 'NEE',
    'nextera energy': 'NEE',
    'duke energy': 'DUK',
    'southern company': 'SO',
    'dominion': 'D',
    'dominion energy': 'D',
    'exelon': 'EXC',
    'exelon corporation': 'EXC',
    'american electric power': 'AEP',
    'aep': 'AEP',
    
    // Aerospace & Defense
    'boeing': 'BA',
    'boeing company': 'BA',
    'lockheed martin': 'LMT',
    'lockheed': 'LMT',
    'raytheon': 'RTX',
    'raytheon technologies': 'RTX',
    'northrop grumman': 'NOC',
    'general dynamics': 'GD',
    'airbus': 'EADSY',
    'spacex': 'SPACE',
    
    // Automotive
    'ford': 'F',
    'ford motor': 'F',
    'ford motor company': 'F',
    'general motors': 'GM',
    'gm': 'GM',
    'toyota': 'TM',
    'toyota motor': 'TM',
    'honda': 'HMC',
    'honda motor': 'HMC',
    'volkswagen': 'VWAGY',
    'vw': 'VWAGY',
    'ferrari': 'RACE',
    'ferrari nv': 'RACE',
    'stellantis': 'STLA',
    'chrysler': 'STLA',
    'fiat': 'STLA',
    'rivian': 'RIVN',
    'rivian automotive': 'RIVN',
    'lucid': 'LCID',
    'lucid motors': 'LCID',
    'lucid group': 'LCID',
    'nio': 'NIO',
    'nio inc': 'NIO',
    'xpeng': 'XPEV',
    'li auto': 'LI',
    
    // Airlines & Travel
    'american airlines': 'AAL',
    'delta': 'DAL',
    'delta air lines': 'DAL',
    'united airlines': 'UAL',
    'southwest': 'LUV',
    'southwest airlines': 'LUV',
    'jetblue': 'JBLU',
    'jetblue airways': 'JBLU',
    'alaska air': 'ALK',
    'alaska airlines': 'ALK',
    'spirit airlines': 'SAVE',
    'frontier': 'ULCC',
    'booking': 'BKNG',
    'booking holdings': 'BKNG',
    'priceline': 'BKNG',
    'expedia': 'EXPE',
    'expedia group': 'EXPE',
    'tripadvisor': 'TRIP',
    'marriott': 'MAR',
    'marriott international': 'MAR',
    'hilton': 'HLT',
    'hilton worldwide': 'HLT',
    'hyatt': 'H',
    'hyatt hotels': 'H',
    'intercontinental': 'IHG',
    'ihg': 'IHG',
    
    // Media & Entertainment
    'disney': 'DIS',
    'walt disney': 'DIS',
    'the walt disney company': 'DIS',
    'comcast': 'CMCSA',
    'comcast corporation': 'CMCSA',
    'verizon': 'VZ',
    'verizon communications': 'VZ',
    'at&t': 'T',
    'att': 'T',
    'at and t': 'T',
    't-mobile': 'TMUS',
    'tmobile': 'TMUS',
    't mobile': 'TMUS',
    'sprint': 'TMUS',
    'warner bros': 'WBD',
    'warner brothers': 'WBD',
    'warner bros discovery': 'WBD',
    'discovery': 'WBD',
    'paramount': 'PARA',
    'paramount global': 'PARA',
    'cbs': 'PARA',
    'viacom': 'PARA',
    'sony': 'SONY',
    'sony corporation': 'SONY',
    'roku': 'ROKU',
    'roku inc': 'ROKU',
    'sirius xm': 'SIRI',
    'siriusxm': 'SIRI',
    
    // Real Estate
    'american tower': 'AMT',
    'crown castle': 'CCI',
    'prologis': 'PLD',
    'simon property': 'SPG',
    'realty income': 'O',
    'welltower': 'WELL',
    'equity residential': 'EQR',
    'avalonbay': 'AVB',
    'boston properties': 'BXP',
    'ventas': 'VTR',
    'host hotels': 'HST',
    'extended stay': 'STAY',
    
    // Industrial & Manufacturing
    'caterpillar': 'CAT',
    'cat': 'CAT',
    'deere': 'DE',
    'john deere': 'DE',
    '3m': 'MMM',
    '3m company': 'MMM',
    'honeywell': 'HON',
    'honeywell international': 'HON',
    'general electric': 'GE',
    'ge': 'GE',
    'siemens': 'SIEGY',
    'emerson': 'EMR',
    'emerson electric': 'EMR',
    'parker hannifin': 'PH',
    'parker': 'PH',
    'illinois tool works': 'ITW',
    'itw': 'ITW',
    'stanley black decker': 'SWK',
    'stanley': 'SWK',
    'ingersoll rand': 'IR',
    'ingersoll-rand': 'IR',
    'carrier': 'CARR',
    'carrier global': 'CARR',
    'otis': 'OTIS',
    'otis worldwide': 'OTIS',
    'trane': 'TT',
    'trane technologies': 'TT',
    'eaton': 'ETN',
    'eaton corporation': 'ETN',
    'cummins': 'CMI',
    'cummins inc': 'CMI',
    'paccar': 'PCAR',
    'paccar inc': 'PCAR',
    'waste management': 'WM',
    'republic services': 'RSG',
    'fedex': 'FDX',
    'fedex corporation': 'FDX',
    'ups': 'UPS',
    'united parcel service': 'UPS',
    'union pacific': 'UNP',
    'csx': 'CSX',
    'csx corporation': 'CSX',
    'norfolk southern': 'NSC',
    'kansas city southern': 'KSU',
    'canadian national': 'CNI',
    'canadian pacific': 'CP',
    
    // Semiconductors (Additional)
    'qualcomm': 'QCOM',
    'qualcomm incorporated': 'QCOM',
    'broadcom': 'AVGO',
    'broadcom inc': 'AVGO',
    'texas instruments': 'TXN',
    'ti': 'TXN',
    'analog devices': 'ADI',
    'micron': 'MU',
    'micron technology': 'MU',
    'applied materials': 'AMAT',
    'lam research': 'LRCX',
    'kla': 'KLAC',
    'kla corporation': 'KLAC',
    'asml': 'ASML',
    'asml holding': 'ASML',
    'taiwan semiconductor': 'TSM',
    'tsmc': 'TSM',
    'sk hynix': 'HXSCF',
    'marvell': 'MRVL',
    'marvell technology': 'MRVL',
    'xilinx': 'XLNX',
    'lattice semiconductor': 'LSCC',
    'microchip': 'MCHP',
    'microchip technology': 'MCHP',
    'maxim integrated': 'MXIM',
    'on semiconductor': 'ON',
    'skyworks': 'SWKS',
    'skyworks solutions': 'SWKS',
    'qorvo': 'QRVO',
    'qorvo inc': 'QRVO',
    
    // Cryptocurrency Related
    'coinbase': 'COIN',
    'coinbase global': 'COIN',
    'marathon digital': 'MARA',
    'marathon': 'MARA',
    'riot blockchain': 'RIOT',
    'riot': 'RIOT',
    'microstrategy': 'MSTR',
    'microstrategy incorporated': 'MSTR',
    'bitcoin': 'BTC-USD',
    'ethereum': 'ETH-USD',
    'litecoin': 'LTC-USD',
    'dogecoin': 'DOGE-USD',
    'cardano': 'ADA-USD',
    'polkadot': 'DOT-USD',
    'chainlink': 'LINK-USD',
    'stellar': 'XLM-USD',
    'ripple': 'XRP-USD',
    
    // Precious Metals & Commodities
    'gold': 'GLD',
    'silver': 'SLV',
    'platinum': 'PPLT',
    'palladium': 'PALL',
    'oil': 'USO',
    'crude oil': 'USO',
    'natural gas': 'UNG',
    'copper': 'CPER',
    'wheat': 'WEAT',
    'corn': 'CORN',
    'soybeans': 'SOYB',
    'sugar': 'SGG',
    'coffee': 'JO',
    'cotton': 'BAL',
    
    // ETFs and Index Funds
    'spy': 'SPY',
    's&p 500': 'SPY',
    'sp 500': 'SPY',
    's and p 500': 'SPY',
    'nasdaq': 'QQQ',
    'nasdaq 100': 'QQQ',
    'qqq': 'QQQ',
    'russell 2000': 'IWM',
    'iwm': 'IWM',
    'dow jones': 'DIA',
    'dow': 'DIA',
    'dia': 'DIA',
    'vti': 'VTI',
    'total stock market': 'VTI',
    'voo': 'VOO',
    'vanguard s&p 500': 'VOO',
    'vig': 'VIG',
    'dividend appreciation': 'VIG',
    'vym': 'VYM',
    'high dividend yield': 'VYM',
    'vteb': 'VTEB',
    'tax exempt bond': 'VTEB',
    'bnd': 'BND',
    'total bond market': 'BND',
    'tlt': 'TLT',
    'treasury bond': 'TLT',
    'xlk': 'XLK',
    'technology': 'XLK',
    'xlf': 'XLF',
    'financial': 'XLF',
    'xle': 'XLE',
    'energy': 'XLE',
    'xlv': 'XLV',
    'healthcare': 'XLV',
    'xlp': 'XLP',
    'consumer staples': 'XLP',
    'xly': 'XLY',
    'consumer discretionary': 'XLY',
    'xli': 'XLI',
    'industrial': 'XLI',
    'xlb': 'XLB',
    'materials': 'XLB',
    'xlre': 'XLRE',
    'real estate': 'XLRE',
    'xlu': 'XLU',
    'utilities': 'XLU',
  };

  /// Searches for stock symbols based on company name
  /// Returns a list of matching symbols with relevance scoring
  static List<String> searchSymbols(String query) {
    if (query.trim().isEmpty) return [];
    
    final searchTerm = query.toLowerCase().trim();
    final results = <String>[];
    final exactMatches = <String>[];
    final partialMatches = <String>[];
    
    // First pass: look for exact matches and partial matches
    _companyToSymbol.forEach((companyName, symbol) {
      if (companyName == searchTerm) {
        // Exact match - highest priority
        if (!exactMatches.contains(symbol)) {
          exactMatches.add(symbol);
        }
      } else if (companyName.contains(searchTerm) || searchTerm.contains(companyName)) {
        // Partial match - lower priority
        if (!partialMatches.contains(symbol) && !exactMatches.contains(symbol)) {
          partialMatches.add(symbol);
        }
      }
    });
    
    // Also check if the search term itself is a symbol
    final symbolUpperCase = searchTerm.toUpperCase();
    if (_companyToSymbol.containsValue(symbolUpperCase)) {
      if (!exactMatches.contains(symbolUpperCase)) {
        exactMatches.insert(0, symbolUpperCase);
      }
    }
    
    // Combine results: exact matches first, then partial matches
    results.addAll(exactMatches);
    results.addAll(partialMatches);
    
    // Limit results to prevent too many suggestions
    return results.take(10).toList();
  }
  
  /// Gets the company name for a given symbol (reverse lookup)
  static String? getCompanyName(String symbol) {
    final symbolUpper = symbol.toUpperCase();
    
    // Find the first company name that maps to this symbol
    for (final entry in _companyToSymbol.entries) {
      if (entry.value.toUpperCase() == symbolUpper) {
        // Return a properly formatted company name
        return _formatCompanyName(entry.key);
      }
    }
    
    return null;
  }
  
  /// Formats company name for display (capitalizes first letter of each word)
  static String _formatCompanyName(String name) {
    return name.split(' ')
        .map((word) => word.isEmpty ? word : 
              word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }
  
  /// Checks if a symbol exists in our mapping
  static bool isKnownSymbol(String symbol) {
    return _companyToSymbol.containsValue(symbol.toUpperCase());
  }
  
  /// Gets all available symbols
  static List<String> getAllSymbols() {
    return _companyToSymbol.values.toSet().toList()..sort();
  }
  
  /// Gets popular symbols (most commonly searched)
  static List<String> getPopularSymbols() {
    return [
      'AAPL', 'MSFT', 'GOOGL', 'AMZN', 'TSLA', 'META', 'NVDA', 'NFLX',
      'SPY', 'QQQ', 'WMT', 'JPM', 'JNJ', 'V', 'PG', 'UNH', 'HD', 'DIS',
      'MA', 'BAC', 'XOM', 'CVX', 'ABBV', 'LLY', 'KO', 'PFE', 'TMO', 'COST'
    ];
  }
  
  /// Search for a stock symbol by company name
  /// Returns the exact symbol if found, null otherwise
  static String? getSymbolFromCompanyName(String companyName) {
    final normalizedName = companyName.toLowerCase().trim();
    return _companyToSymbol[normalizedName];
  }
  
  /// Search for symbols that partially match the company name
  /// Returns a list of matching symbols
  static List<String> searchSymbolsByCompanyName(String query) {
    final normalizedQuery = query.toLowerCase().trim();
    final matches = <String>[];
    
    for (final entry in _companyToSymbol.entries) {
      if (entry.key.contains(normalizedQuery)) {
        if (!matches.contains(entry.value)) {
          matches.add(entry.value);
        }
      }
    }
    
    return matches;
  }
  
  /// Get company name from symbol (reverse lookup)
  /// Returns the first matching company name for the symbol
  static String? getCompanyNameFromSymbol(String symbol) {
    final normalizedSymbol = symbol.toUpperCase().trim();
    
    for (final entry in _companyToSymbol.entries) {
      if (entry.value == normalizedSymbol) {
        return entry.key;
      }
    }
    
    return null;
  }
}
