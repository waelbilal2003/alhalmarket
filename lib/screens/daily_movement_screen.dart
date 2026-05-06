import 'package:flutter/material.dart';
import '../services/store_db_service.dart';
import 'seller_management_screen.dart';
import 'daily_movement/yield_screen.dart' as DailyMovementYield;
import 'daily_movement/purchases_screen.dart';
import 'daily_movement/sales_screen.dart';
import 'daily_movement/receipt_screen.dart';
import 'daily_movement/box_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'bait_screen.dart';
import 'daily_movement/invoice_type_selection_screen.dart';
import 'account_summary_screen.dart';
import 'backup_screen_state.dart';
import 'package:flutter/services.dart';
import '../widgets/exit_button.dart';

class DailyMovementScreen extends StatefulWidget {
  final String selectedDate;
  final String storeType;
  final String sellerName;

  const DailyMovementScreen({
    super.key,
    required this.selectedDate,
    required this.storeType,
    required this.sellerName,
  });

  @override
  State<DailyMovementScreen> createState() => _DailyMovementScreenState();
}

class _DailyMovementScreenState extends State<DailyMovementScreen> {
  String _storeName = '';

  // متغيرات نظام التحكم بالأسهم والمؤشر الذهبي
  late List<FocusNode> _focusNodes;
  int _focusedIndex = 0;
  bool _isSmallScreen = false;
  final FocusNode _globalFocusNode = FocusNode();

  // تعريف جميع الأزرار في مصفوفة واحدة
  late final List<Map<String, dynamic>> _buttons;

  @override
  void initState() {
    super.initState();
    _loadStoreName();
    _initButtons();
    _focusNodes = List.generate(_buttons.length, (_) => FocusNode());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes[0].requestFocus();
        _focusedIndex = 0;
        setState(() {});
      }
    });
  }

  void _initButtons() {
    _buttons = [
      // الصف الأول (5 أزرار: 0-4)
      {
        'icon': Icons.inventory,
        'label': 'الاستلام',
        'color': Colors.blue[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ReceiptScreen(
                sellerName: widget.sellerName,
                selectedDate: widget.selectedDate,
                storeName: _storeName,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.point_of_sale,
        'label': 'المبيعات',
        'color': Colors.orange[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => SalesScreen(
                sellerName: widget.sellerName,
                selectedDate: widget.selectedDate,
                storeName: _storeName,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.shopping_cart,
        'label': 'المشتريات',
        'color': Colors.red[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => PurchasesScreen(
                sellerName: widget.sellerName,
                selectedDate: widget.selectedDate,
                storeName: _storeName,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.receipt_long,
        'label': 'الفواتير',
        'color': Colors.indigo[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => InvoiceTypeSelectionScreen(
                selectedDate: widget.selectedDate,
                storeName: _storeName,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.account_balance,
        'label': 'الصندوق',
        'color': Colors.blueGrey[600]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BoxScreen(
                sellerName: widget.sellerName,
                selectedDate: widget.selectedDate,
                storeName: _storeName,
              ),
            ),
          );
        },
      },
      // الصف الثاني (5 أزرار: 5-9)
      {
        'icon': Icons.grain,
        'label': 'الغلة',
        'color': Colors.purple[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => DailyMovementYield.YieldScreen(
                sellerName: widget.sellerName,
                password: '******',
                selectedDate: widget.selectedDate,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.inventory_2,
        'label': 'البايت',
        'color': Colors.teal[700]!,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => BaitScreen(
                selectedDate: widget.selectedDate,
              ),
            ),
          );
        },
      },
      {
        'icon': Icons.settings,
        'label': 'الخدمات',
        'color': Colors.grey[600]!,
        'onTap': () async {
          final isAdmin = await _isAdminSeller(widget.sellerName);
          if (isAdmin) {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => SellerManagementScreen(
                  currentStoreName: _storeName,
                  onLogout: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('عفواً، هذه الخدمة متاحة فقط للإدارة'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        },
      },
      {
        'icon': Icons.backup,
        'label': 'النسخ\nالاحتياطي',
        'color': const Color(0xFF0F4C5C),
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const BackupScreen(),
            ),
          );
        },
      },
      {
        'icon': Icons.account_balance,
        'label': 'تفصيلات\nالحساب',
        'color': Colors.indigo,
        'onTap': () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AccountSummaryScreen(
                selectedDate: widget.selectedDate,
              ),
            ),
          );
        },
      },
    ];
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    _globalFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadStoreName() async {
    final storeDbService = StoreDbService();
    final savedStoreName = await storeDbService.getStoreName();
    setState(() {
      _storeName = savedStoreName ?? widget.storeType;
    });
  }

  void _handleBackButton() {
    Navigator.of(context).pop();
  }

  // ============== نظام التحكم بلوحة المفاتيح ==============

  void _handleKeyEvent(RawKeyEvent event) {
    if (event is! RawKeyDownEvent) return;

    final key = event.logicalKey;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocusLeft();
    } else if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocusRight();
    } else if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocusUp();
    } else if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocusDown();
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.space) {
      _executeCurrentFocus();
    } else if (key == LogicalKeyboardKey.escape) {
      _handleBackButton();
    }
  }

  void _moveFocusLeft() {
    if (_isSmallScreen) return;

    // التنقل يساراً في نفس الصف (RTL)
    // الصف الأول: 0-4، الصف الثاني: 5-9
    // كل صف فيه 5 أعمدة
    if (_focusedIndex % 5 < 4) {
      _setFocus(_focusedIndex + 1);
    }
  }

  void _moveFocusRight() {
    if (_isSmallScreen) return;

    // التنقل يميناً في نفس الصف (RTL)
    if (_focusedIndex % 5 > 0) {
      _setFocus(_focusedIndex - 1);
    }
  }

  void _moveFocusUp() {
    if (_isSmallScreen) {
      if (_focusedIndex > 0) _setFocus(_focusedIndex - 1);
      return;
    }

    // من الصف الثاني إلى الأول
    if (_focusedIndex >= 5 && _focusedIndex <= 9) {
      _setFocus(_focusedIndex - 5);
    }
  }

  void _moveFocusDown() {
    if (_isSmallScreen) {
      if (_focusedIndex < 9) _setFocus(_focusedIndex + 1);
      return;
    }

    // من الصف الأول إلى الثاني
    if (_focusedIndex >= 0 && _focusedIndex <= 4) {
      _setFocus(_focusedIndex + 5);
    }
  }

  void _setFocus(int index) {
    if (!mounted) return;
    setState(() {
      _focusedIndex = index;
    });
    _globalFocusNode.requestFocus();
  }

  void _executeCurrentFocus() {
    final button = _buttons[_focusedIndex];
    if (button['onTap'] != null) {
      (button['onTap'] as VoidCallback)();
    }
  }

  // ============== بناء الواجهة ==============

  @override
  Widget build(BuildContext context) {
    return RawKeyboardListener(
      focusNode: _globalFocusNode,
      autofocus: true,
      onKey: _handleKeyEvent,
      child: WillPopScope(
        onWillPop: () async {
          Navigator.of(context).pop();
          return false;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(
              'الحركة اليومية لتاريخ ${widget.selectedDate} البائع ${widget.sellerName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: Colors.green[600],
            foregroundColor: Colors.white,
            leadingWidth: 100, // ← أضف هذا السطر لتوسيع مساحة الـ leading
            leading: ExitButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              width: 80, // العرض المطلوب
              height: 40, // الارتفاع المطلوب
              text: 'خروج',
            ),
          ),
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: LayoutBuilder(
              builder: (context, constraints) {
                _isSmallScreen = constraints.maxWidth < 500;

                return Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 2, horizontal: 24),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 1,
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10.0, vertical: 50.0),
                        child: _isSmallScreen
                            ? _buildSmallScreenLayout()
                            : _buildLargeScreenLayout(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        // الصف الأول (5 أزرار: 0-4)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[0]['icon'],
                label: _buttons[0]['label'],
                color: _buttons[0]['color'],
                index: 0,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[1]['icon'],
                label: _buttons[1]['label'],
                color: _buttons[1]['color'],
                index: 1,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[2]['icon'],
                label: _buttons[2]['label'],
                color: _buttons[2]['color'],
                index: 2,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[3]['icon'],
                label: _buttons[3]['label'],
                color: _buttons[3]['color'],
                index: 3,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[4]['icon'],
                label: _buttons[4]['label'],
                color: _buttons[4]['color'],
                index: 4,
              ),
            ),
          ],
        ),
        const SizedBox(height: 50.0),
        // الصف الثاني (5 أزرار: 5-9)
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[5]['icon'],
                label: _buttons[5]['label'],
                color: _buttons[5]['color'],
                index: 5,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[6]['icon'],
                label: _buttons[6]['label'],
                color: _buttons[6]['color'],
                index: 6,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[7]['icon'],
                label: _buttons[7]['label'],
                color: _buttons[7]['color'],
                index: 7,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[8]['icon'],
                label: _buttons[8]['label'],
                color: _buttons[8]['color'],
                index: 8,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: _buildMenuButton(
                context,
                icon: _buttons[9]['icon'],
                label: _buttons[9]['label'],
                color: _buttons[9]['color'],
                index: 9,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSmallScreenLayout() {
    return SingleChildScrollView(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (int i = 0; i < _buttons.length; i++)
            Column(
              children: [
                _buildMenuButton(
                  context,
                  icon: _buttons[i]['icon'],
                  label: _buttons[i]['label'],
                  color: _buttons[i]['color'],
                  index: i,
                ),
                if (i < _buttons.length - 1) const SizedBox(height: 16),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required int index,
  }) {
    final isServicesButton = label.contains('الخدمات');
    final hasFocus = _focusedIndex == index;
    final buttonHeight = (MediaQuery.of(context).size.width / 4) / 1.5;

    return FutureBuilder<bool>(
      future: isServicesButton
          ? _isAdminSeller(widget.sellerName)
          : Future.value(true),
      builder: (context, snapshot) {
        final isAdmin = snapshot.data ?? false;
        final isEnabled = !isServicesButton || isAdmin;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.identity()..scale(hasFocus ? 1.05 : 1.0),
          child: Material(
            elevation: hasFocus ? 20 : 8,
            borderRadius: BorderRadius.circular(20),
            shadowColor: hasFocus ? Colors.amber : color.withOpacity(0.5),
            child: InkWell(
              onTap: isEnabled
                  ? () {
                      _setFocus(index);
                      final button = _buttons[index];
                      if (button['onTap'] != null) {
                        (button['onTap'] as VoidCallback)();
                      }
                    }
                  : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: buttonHeight,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: hasFocus
                        ? [Colors.amber.shade600, Colors.orange.shade800]
                        : [
                            isEnabled ? color : Colors.grey[400]!,
                            isEnabled
                                ? color.withOpacity(0.7)
                                : Colors.grey[300]!
                          ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: hasFocus
                      ? Border.all(color: Colors.black, width: 6)
                      : Border.all(color: Colors.transparent, width: 4),
                  boxShadow: hasFocus
                      ? [
                          BoxShadow(
                            color: Colors.amber.withOpacity(0.6),
                            blurRadius: 25,
                            spreadRadius: 3,
                            offset: const Offset(0, 0),
                          ),
                        ]
                      : isEnabled
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedRotation(
                      turns: hasFocus ? 0.05 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: AnimatedScale(
                        scale: hasFocus ? 1.2 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          icon,
                          size: hasFocus ? 85 : 70,
                          color: hasFocus
                              ? Colors.yellowAccent
                              : (isEnabled ? Colors.white : Colors.grey[200]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isEnabled ? Colors.white : Colors.grey[200],
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        shadows: hasFocus
                            ? [
                                const Shadow(
                                  color: Colors.black26,
                                  blurRadius: 4,
                                )
                              ]
                            : null,
                      ),
                    ),
                    if (isServicesButton && isAdmin)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Icon(
                          Icons.star,
                          size: hasFocus ? 35 : 30,
                          color: Colors.yellow,
                        ),
                      ),
                    if (hasFocus)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Container(
                          width: 40,
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _isAdminSeller(String sellerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final adminSeller = prefs.getString('admin_seller');
      if (adminSeller == null) {
        final accountsJson = prefs.getString('accounts');
        if (accountsJson != null) {
          final accounts = json.decode(accountsJson) as Map<String, dynamic>;
          if (accounts.isNotEmpty) {
            final firstSeller = accounts.keys.first;
            await prefs.setString('admin_seller', firstSeller);
            return firstSeller == sellerName;
          }
        }
        return false;
      }
      return adminSeller == sellerName;
    } catch (e) {
      print('خطأ في التحقق من الادمن: $e');
      return false;
    }
  }
}
