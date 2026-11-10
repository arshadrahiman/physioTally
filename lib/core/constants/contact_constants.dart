class ContactConstants {
  static const String supportPhone = '+919645808999';
  static const String supportWhatsApp = '+919645808999';
  static const String supportEmail = 'arshadrahman.dev@gmail.com';

  static String getWhatsAppUrl({String planName = 'Annual Pro'}) {
    final message = Uri.encodeComponent(
      'Hello Arshad, I would like to subscribe to PhysioTally Pro ($planName). Please share payment details and activation code.',
    );
    // WhatsApp international number without '+'
    final cleanPhone = supportWhatsApp.replaceAll('+', '').replaceAll(' ', '');
    return 'https://wa.me/$cleanPhone?text=$message';
  }

  static String getPhoneUri() {
    return 'tel:$supportPhone';
  }

  static String getEmailUri({String planName = 'Annual Pro'}) {
    final subject = Uri.encodeComponent('PhysioTally Pro Subscription - $planName');
    final body = Uri.encodeComponent(
      'Hello Arshad,\n\nI want to subscribe to the PhysioTally Pro tier ($planName) for my physiotherapy practice.\n\nPlease provide payment and activation details.\n\nThank you!',
    );
    return 'mailto:$supportEmail?subject=$subject&body=$body';
  }
}
