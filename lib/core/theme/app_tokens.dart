import 'package:flutter/material.dart';

/// Token warna dari `design_ui.pen`.
///
/// Nama variabel di file desain: `$primary`, `$ink`, `$muted`, `$canvas`,
/// `$line`, `$success`, `$warning`. Nilai di bawah ini harus sama persis
/// supaya aplikasi dan desain tidak pernah "bergeser" satu sama lain.
abstract final class AppPalette {
  static const primary = Color(0xFF245FE5);
  static const primaryTint = Color(0xFFEBF1FF);
  static const primarySoft = Color(0xFFDCE7FF);

  static const ink = Color(0xFF17243B);
  static const muted = Color(0xFF69758A);
  static const canvas = Color(0xFFF5F7FB);
  static const line = Color(0xFFE5EAF2);
  static const surface = Color(0xFFFFFFFF);

  static const success = Color(0xFF147D61);
  static const successTint = Color(0xFFE9F6F0);

  static const warning = Color(0xFF996310);
  static const warningTint = Color(0xFFFFF4DE);

  static const danger = Color(0xFFBC3F50);
  static const dangerTint = Color(0xFFFDEDEF);
}

/// Radius & jarak yang dipakai berulang di desain.
abstract final class AppRadius {
  /// Kartu, panel, dan baris daftar.
  static const card = 10.0;

  /// Tombol, input, chip persegi.
  static const control = 8.0;

  /// Lencana kecil (status, kategori).
  static const badge = 6.0;

  /// Ikon/logo persegi di rail dan sidebar.
  static const tile = 12.0;

  /// Pil penuh (segmented control, filter bundar).
  static const pill = 999.0;
}

abstract final class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;

  /// Jarak tepi halaman standar di HP.
  static const pagePhone = EdgeInsets.fromLTRB(16, 16, 16, 24);

  /// Jarak tepi halaman standar di tablet & web.
  static const pageWide = EdgeInsets.fromLTRB(24, 20, 24, 28);
}

/// Titik henti tata letak.
///
/// * `< [phone]`  → bilah navigasi bawah (HP).
/// * `>= [tablet]` → rel ikon (tablet).
/// * `>= [desktop]` → sidebar penuh (web).
abstract final class Breakpoints {
  static const phone = 600.0;
  static const tablet = 1000.0;
  static const desktop = tablet;

  /// Lebar rail ikon pada tablet, sesuai frame `Tablet / …`.
  static const railWidth = 76.0;

  /// Lebar sidebar penuh pada web, sesuai frame `Owner / …`.
  static const sidebarWidth = 224.0;
}

enum DeviceClass { phone, tablet, desktop }

DeviceClass deviceClassOf(double width) {
  if (width >= Breakpoints.desktop) return DeviceClass.desktop;
  if (width >= Breakpoints.phone) return DeviceClass.tablet;
  return DeviceClass.phone;
}

/// Token tambahan yang tidak tersedia di [ColorScheme] Material 3.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.canvas,
    required this.ink,
    required this.muted,
    required this.line,
    required this.success,
    required this.successTint,
    required this.warning,
    required this.warningTint,
    required this.danger,
    required this.dangerTint,
    required this.primaryTint,
  });

  final Color canvas;
  final Color ink;
  final Color muted;
  final Color line;
  final Color success;
  final Color successTint;
  final Color warning;
  final Color warningTint;
  final Color danger;
  final Color dangerTint;
  final Color primaryTint;

  static const light = AppTokens(
    canvas: AppPalette.canvas,
    ink: AppPalette.ink,
    muted: AppPalette.muted,
    line: AppPalette.line,
    success: AppPalette.success,
    successTint: AppPalette.successTint,
    warning: AppPalette.warning,
    warningTint: AppPalette.warningTint,
    danger: AppPalette.danger,
    dangerTint: AppPalette.dangerTint,
    primaryTint: AppPalette.primaryTint,
  );

  static const dark = AppTokens(
    canvas: Color(0xFF0F1521),
    ink: Color(0xFFF2F5FA),
    muted: Color(0xFF9AA6BC),
    line: Color(0xFF28324A),
    success: Color(0xFF5CC9A7),
    successTint: Color(0xFF14332B),
    warning: Color(0xFFE0B25E),
    warningTint: Color(0xFF3A2E12),
    danger: Color(0xFFF08B99),
    dangerTint: Color(0xFF3B1B21),
    primaryTint: Color(0xFF1B2A4E),
  );

  @override
  AppTokens copyWith({
    Color? canvas,
    Color? ink,
    Color? muted,
    Color? line,
    Color? success,
    Color? successTint,
    Color? warning,
    Color? warningTint,
    Color? danger,
    Color? dangerTint,
    Color? primaryTint,
  }) {
    return AppTokens(
      canvas: canvas ?? this.canvas,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      success: success ?? this.success,
      successTint: successTint ?? this.successTint,
      warning: warning ?? this.warning,
      warningTint: warningTint ?? this.warningTint,
      danger: danger ?? this.danger,
      dangerTint: dangerTint ?? this.dangerTint,
      primaryTint: primaryTint ?? this.primaryTint,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      success: Color.lerp(success, other.success, t)!,
      successTint: Color.lerp(successTint, other.successTint, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningTint: Color.lerp(warningTint, other.warningTint, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      dangerTint: Color.lerp(dangerTint, other.dangerTint, t)!,
      primaryTint: Color.lerp(primaryTint, other.primaryTint, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>() ?? AppTokens.light;

  DeviceClass get deviceClass => deviceClassOf(MediaQuery.sizeOf(this).width);
}
