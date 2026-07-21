import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';

class RoleBadge extends StatelessWidget {
  final String role;
  final bool small;

  const RoleBadge({
    super.key,
    required this.role,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _roleConfig(role);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: config.color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: config.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: small ? 10 : 12, color: config.color),
          const SizedBox(width: 4),
          Text(
            config.label,
            style: AppTextStyles.labelSmall.copyWith(
              color: config.color,
              fontSize: small ? 9 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  _RoleConfig _roleConfig(String role) {
    switch (role) {
      case 'farmer':
        return _RoleConfig(AppColors.farmerRole, '🌾 Farmer', Icons.agriculture);
      case 'expert':
        return _RoleConfig(AppColors.expertRole, '🎓 Expert', Icons.school);
      case 'lecturer':
        return _RoleConfig(AppColors.expertRole, '📚 Lecturer', Icons.menu_book);
      case 'consultant':
        return _RoleConfig(AppColors.expertRole, '💼 Consultant', Icons.business_center);
      case 'truck_driver':
        return _RoleConfig(AppColors.driverRole, '🚛 Driver', Icons.local_shipping);
      case 'processing_industry':
        return _RoleConfig(AppColors.businessRole, '🏭 Processor', Icons.factory);
      case 'wholesaler':
        return _RoleConfig(AppColors.businessRole, '📦 Wholesaler', Icons.warehouse);
      case 'retailer':
        return _RoleConfig(AppColors.businessRole, '🏪 Retailer', Icons.store);
      case 'enthusiast':
        return _RoleConfig(AppColors.enthusiastRole, '🌱 Enthusiast', Icons.favorite);
      case 'customer':
        return _RoleConfig(AppColors.customerRole, '🛒 Customer', Icons.shopping_cart);
      case 'admin':
        return _RoleConfig(AppColors.error, '⚙️ Admin', Icons.admin_panel_settings);
      default:
        return _RoleConfig(AppColors.textTertiary, role, Icons.person);
    }
  }
}

class _RoleConfig {
  final Color color;
  final String label;
  final IconData icon;
  _RoleConfig(this.color, this.label, this.icon);
}
