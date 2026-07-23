// Centralised legal copy for the app. All content here is templated — before
// going to production, have a lawyer licensed in India review every document,
// fill in the bracketed [PLACEHOLDERS], and confirm the company details and
// grievance officer match your registered entity.

class LegalSection {
  const LegalSection({required this.heading, required this.body});
  final String heading;
  final String body;
}

class LegalDocument {
  const LegalDocument({
    required this.title,
    required this.lastUpdated,
    required this.intro,
    required this.sections,
    this.showFooter = true,
  });

  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;
  // Whether to render the "This document is part of the Service…"
  // boilerplate footer under the sections. Kept on for the heavy legal
  // docs (Privacy, Terms, Refund) where the severability clause matters;
  // turned off for About / Disclaimer / Contact where it's just noise.
  final bool showFooter;
}

abstract final class LegalContent {
  // Customer-facing brand values. Grievance officer email intentionally
  // stays on the cpnetwork.in domain because it's the entity's
  // DPDP-registered redressal address.
  static const String companyName = 'CP Network Private Limited';
  static const String officeAddress =
      '401, Antriksh Building, Makhwana Road, Marol Andheri East, Mumbai, Maharashtra 400069';
  static const String supportEmail = 'support@qr4emergency.com';
  static const String legalEmail = 'support@qr4emergency.com';
  static const String billingEmail = 'support@qr4emergency.com';
  static const String grievanceEmail = 'grievance@cpnetwork.in';
  static const String grievanceOfficer = 'Grievance Redressal Officer';
  static const String supportPhone = '+91-9665108102';
  static const String websiteUrl = 'www.qr4emergency.com';

  // ─── Privacy Policy ─────────────────────────────────────────────────────
  // Source: CP Network Private Limited official Privacy Policy document
  // (QR4Emergency_Privacy_Policy.pdf), effective 25 June 2026.
  static const privacyPolicy = LegalDocument(
    title: 'Privacy Policy',
    lastUpdated: '25 June 2026',
    intro:
        'QR 4 Emergency is a QR Code Vehicle Emergency Contact & Smart '
        'Parking Solution operated by CP Network Private Limited.\n\n'
        'Head Office: $officeAddress\n'
        'Email: $supportEmail\n'
        'Effective Date: 25 June 2026',
    sections: [
      LegalSection(
        heading: '1. Introduction & Scope',
        body:
            'Welcome to QR 4 Emergency ("App", "Service", "Platform"). We '
            'are committed to protecting your personal information and '
            'complying with the Digital Personal Data Protection Act, '
            '2023 (DPDP Act), the Information Technology Act, 2000, and '
            'other applicable laws.\n\n'
            'This Privacy Policy explains:\n'
            '• What information we collect\n'
            '• How we use it\n'
            '• How we protect it\n'
            '• Your rights regarding your information\n\n'
            'This Policy applies to all users of the QR 4 Emergency mobile '
            'application and related web services.\n\n'
            'By registering or using QR 4 Emergency, you agree to this '
            'Privacy Policy.',
      ),
      LegalSection(
        heading: '2. Information We Collect',
        body:
            'We collect only the information necessary to provide our '
            'services.\n\n'
            '2.1 Data You Provide Directly\n\n'
            'When you create an account, we collect:\n'
            '• Full Name\n'
            '• Mobile Number (required for OTP verification)\n'
            '• Vehicle Number\n'
            '• Emergency Contacts (minimum 1 and maximum 5), including '
            'each contact\'s name and mobile number.\n'
            '• Blood Group (Mandatory) — Required to help emergency '
            'responders and first responders identify your blood group '
            'during emergencies when your QR code is scanned.\n'
            '• Shipping Address (Mandatory) — Required to process, ship, '
            'and deliver your purchased QR sticker. This may include your '
            'name, address, city, state, postal code, and contact number.\n\n'
            'We do not require your RC details, vehicle make, model, or '
            'other vehicle information to use the Service.\n\n'
            '2.2 Data Collected Automatically\n\n'
            'With your permission, we may collect:\n'
            '• Device information (device model, operating system, app '
            'version, IP address, crash logs, and performance data)\n'
            '• QR scan information (date, time, QR ID, and usage logs)\n'
            '• Camera permission (to scan QR codes)\n'
            '• Location (Optional): If a person scans your QR code, they '
            'may choose to share their location with you. Location sharing '
            'is completely optional and is only shared with your consent.\n'
            '• Call Details: After a call is completed through our call '
            'masking service, the vehicle owner may receive call '
            'information such as the caller\'s phone number (if shared), '
            'date and time of the call, and call duration for reference '
            'and safety purposes.\n\n'
            'We do not collect sensitive personal information such as '
            'financial information, biometrics, or health information.',
      ),
      LegalSection(
        heading: '3. How We Use Your Information',
        body:
            'We use your information to:\n'
            '• Create and manage your account.\n'
            '• Link your QR code with your vehicle.\n'
            '• Connect QR scanners with vehicle owners through secure '
            'call masking.\n'
            '• Notify vehicle owners regarding emergencies or parking '
            'issues.\n'
            '• Maintain call history and service records.\n'
            '• Improve app performance and security.\n'
            '• Detect fraud and misuse.\n'
            '• Comply with legal obligations.\n\n'
            'We do not sell your personal information or use it for '
            'targeted advertising.',
      ),
      LegalSection(
        heading: '4. How We Share Your Information',
        body:
            'We never sell or rent your personal information.\n\n'
            'Your information may be shared only with:\n'
            '• Telecom and call masking providers to enable secure '
            'communication.\n'
            '• Cloud hosting and technical service providers.\n'
            '• Government authorities when legally required.',
      ),
      LegalSection(
        heading: '5. Data Retention',
        body:
            'We retain data only as long as necessary.\n'
            '• Account information remains until you delete your account.\n'
            '• Call and scan logs may be retained for up to 12 months.\n'
            '• Technical logs may be retained for up to 90 days.\n'
            '• Deleted accounts are removed or anonymized as required by '
            'law.',
      ),
      LegalSection(
        heading: '6. Your Rights',
        body:
            'You have the right to:\n'
            '• Access your personal data.\n'
            '• Correct inaccurate information.\n'
            '• Delete your account and personal data.\n'
            '• Withdraw consent.\n'
            '• File a grievance.\n'
            '• Nominate another person to exercise your rights where '
            'applicable.\n\n'
            'You can exercise these rights through:\n'
            '• App Settings\n'
            '• Email: $supportEmail',
      ),
      LegalSection(
        heading: '7. Security',
        body:
            'We use industry-standard security measures, including '
            'encryption, secure servers, restricted access, and regular '
            'security monitoring to protect your information.\n\n'
            'Although we take reasonable precautions, no online system '
            'can guarantee complete security.',
      ),
      LegalSection(
        heading: "8. Children's Privacy",
        body:
            'QR 4 Emergency is intended for users aged 18 years and above.\n\n'
            'We do not knowingly collect information from children.',
      ),
      LegalSection(
        heading: '9. International Data Transfers',
        body:
            'Your information is primarily stored and processed in India.\n\n'
            'If data is transferred outside India, appropriate safeguards '
            'will be implemented.',
      ),
      LegalSection(
        heading: '10. Cookies & Analytics',
        body:
            'The app uses only essential storage and analytics required '
            'for service improvement.\n\n'
            'We do not use third-party advertising or cross-app tracking.',
      ),
      LegalSection(
        heading: '11. Changes to This Policy',
        body:
            'We may update this Privacy Policy from time to time.\n\n'
            'Any significant changes will be communicated through the app '
            'or by updating the Effective Date.',
      ),
      LegalSection(
        heading: '12. Grievance Officer',
        body:
            '$companyName\n'
            'Phone: $supportPhone\n'
            '$officeAddress\n'
            'Email: $grievanceEmail\n\n'
            'We aim to resolve grievances within applicable legal '
            'timelines.',
      ),
      LegalSection(
        heading: '13. Governing Law',
        body:
            'This Privacy Policy is governed by the laws of India.\n\n'
            'Any disputes shall be subject to the jurisdiction of the '
            'courts of Mumbai, Maharashtra.',
      ),
      LegalSection(
        heading: '14. Contact Us',
        body:
            '$companyName\n'
            'Phone: $supportPhone\n'
            '$officeAddress\n'
            'Email: $supportEmail\n\n'
            'Thank you for choosing QR 4 Emergency. Our goal is to help '
            'people connect quickly during emergencies while protecting '
            'your privacy and personal information.',
      ),
    ],
  );

  // ─── Terms & Conditions ────────────────────────────────────────────────
  static const termsAndConditions = LegalDocument(
    title: 'Terms & Conditions',
    lastUpdated: 'July 21, 2026',
    intro:
        'These Terms & Conditions govern your use of QR 4 Emergency, a '
        'service operated by $companyName. By registering, activating, or '
        'using the service, you agree to these Terms.',
    sections: [
      LegalSection(
        heading: '1. Eligibility',
        body:
            '• You must be at least 18 years old.\n'
            '• You may register only vehicles that you own or are '
            'authorized to register.',
      ),
      LegalSection(
        heading: '2. Service',
        body:
            'QR 4 Emergency helps connect a QR scanner with your '
            'nominated emergency contacts through a masked calling system. '
            'It is not an emergency response service and does not replace '
            'Police, Ambulance, Fire, or other emergency services.',
      ),
      LegalSection(
        heading: '3. User Responsibilities',
        body:
            'You agree to:\n'
            '• Provide accurate information.\n'
            '• Keep your emergency contacts updated.\n'
            '• Keep your account and OTP secure.\n'
            '• Use the service only for lawful purposes.',
      ),
      LegalSection(
        heading: '4. Payment',
        body:
            '• One-time payment: ₹499 per QR (inclusive of applicable '
            'taxes).\n'
            '• The payment is for the registered QR and its associated '
            'services.\n'
            '• Each QR requires a separate one-time payment.',
      ),
      LegalSection(
        heading: '5. Refund & Cancellation',
        body:
            '• If a refund is approved after activation, all platform '
            'charges and QR printing charges will be refunded, except '
            'where required by applicable law.',
      ),
      LegalSection(
        heading: '6. Acceptable Use',
        body:
            'You must not:\n'
            '• Register unauthorized vehicles.\n'
            '• Misuse the service or masked calling feature.\n'
            '• Attempt unauthorized access, hacking, reverse engineering, '
            'or data extraction.\n'
            '• Use the service for fraudulent or illegal activities.\n\n'
            'Violation may result in suspension or termination without '
            'refund.',
      ),
      LegalSection(
        heading: '7. Intellectual Property',
        body:
            'All trademarks, software, content, QR designs, and branding '
            'belong to $companyName. No ownership rights are transferred '
            'to users.',
      ),
      LegalSection(
        heading: '8. Disclaimer',
        body:
            'The service is provided on an "AS IS" and "AS AVAILABLE" '
            'basis.\n\n'
            'We do not guarantee:\n'
            '• Successful call connection.\n'
            '• Availability of mobile or internet networks.\n'
            '• That emergency contacts will answer the call.\n'
            '• Continuous or uninterrupted service.\n\n'
            '$companyName shall not be responsible if a call cannot be '
            'completed due to technical issues, telecom/network failures, '
            'server downtime, device issues, or because the nominated '
            'emergency contact does not answer the phone.',
      ),
      LegalSection(
        heading: '9. Limitation of Liability',
        body:
            'To the maximum extent permitted by law, $companyName\'s total '
            'liability shall not exceed the amount paid by you for the '
            'applicable subscription.',
      ),
      LegalSection(
        heading: '10. Account Suspension',
        body:
            'We may suspend or terminate any account involved in fraud, '
            'misuse, illegal activities, or violation of these Terms.',
      ),
      LegalSection(
        heading: '11. Changes to Terms',
        body:
            '$companyName reserves the absolute right to modify, update, '
            'interpret, or replace these Terms & Conditions, Privacy '
            'Policy, pricing, features, or any related policies at any '
            'time. Any such decision shall be final and binding, subject '
            'to applicable law.',
      ),
      LegalSection(
        heading: '12. Governing Law',
        body:
            'These Terms are governed by the laws of India. Courts in '
            'Mumbai, Maharashtra shall have exclusive jurisdiction, '
            'subject to applicable consumer protection laws.',
      ),
      LegalSection(
        heading: '13. Contact',
        body:
            '$companyName\n'
            'Phone: $supportPhone\n'
            'Email: $supportEmail',
      ),
    ],
  );

  // ─── Disclaimer ────────────────────────────────────────────────────────
  static const disclaimer = LegalDocument(
    title: 'Disclaimer',
    lastUpdated: '07 July 2026',
    intro:
        'QR 4 Emergency is a contact-bridging tool. It is NOT a substitute '
        'for emergency services. Read this disclaimer carefully — your '
        'safety depends on understanding what this app can and cannot do.',
    showFooter: false,
    sections: [
      LegalSection(
        heading: 'In a life-threatening situation, dial directly',
        body:
            '• 112 — National Emergency Number (India)\n'
            '• 102 — Ambulance / Medical\n'
            '• 100 — Police\n'
            '• 101 — Fire\n'
            '• 1098 — Childline\n'
            '• 181 — Women\'s helpline\n\n'
            'Do not wait for someone to scan your QR if you can dial these '
            'numbers yourself or ask a bystander to.',
      ),
      LegalSection(
        heading: 'What QR 4 Emergency does',
        body:
            'When a bystander scans your QR, they see masked information '
            'about you and a Call button. Tapping that button opens their '
            'phone dialler with a masked bridge number. If they press dial, '
            'a call is connected to one of your nominated contacts without '
            'either side seeing the other\'s real number.',
      ),
      LegalSection(
        heading: 'What QR 4 Emergency does NOT do',
        body:
            '• We do not dispatch ambulances, paramedics, police, or fire '
            'response.\n'
            '• We do not contact your insurer.\n'
            '• We do not notify hospitals.\n'
            '• We do not guarantee that any nominated contact will answer.\n'
            '• We do not guarantee that the scanner will press the Call '
            'button.\n'
            '• We do not guarantee that the mobile network, our telephony '
            'bridge, or our servers will be available at the moment of an '
            'emergency.',
      ),
      LegalSection(
        heading: 'Your responsibilities',
        body:
            '• Keep your emergency contacts current. Out-of-date contacts '
            'render the Service useless.\n'
            '• Verify that your QR sticker is visible and undamaged on your '
            'vehicle.\n'
            '• Educate household members and frequent passengers about how '
            'the QR works.\n'
            '• Be aware of the local emergency services in your area.',
      ),
    ],
  );

  // ─── About ─────────────────────────────────────────────────────────────
  static const about = LegalDocument(
    title: 'About QR 4 Emergency',
    lastUpdated: '07 July 2026',
    intro:
        'QR 4 Emergency is a connectivity tool for vehicle owners in India.',
    showFooter: false,
    sections: [
      LegalSection(
        heading: 'Our mission',
        body:
            'To lower the time-to-contact in roadside emergencies, without '
            'compromising the privacy of either the vehicle owner or the '
            'person trying to help.',
      ),
      LegalSection(
        heading: 'How it works',
        body:
            'Our QR codes are designed to live on the windshield of your '
            'vehicle. A bystander, paramedic, or fellow motorist can scan '
            'the code with any phone camera. A masked phone bridge then '
            'connects them directly to your nominated emergency contacts, '
            'without ever exposing either party\'s real phone number.\n\n'
            'No app install is required for the scanner — any phone with a '
            'camera works.',
      ),
      LegalSection(
        heading: 'Who we are',
        body:
            '$companyName is an independent company based in Mumbai, India. '
            'We are not affiliated with any government emergency service, '
            'insurance company, or vehicle manufacturer. We are funded '
            'entirely by our subscribers — we do not sell or share your '
            'data with advertisers or data brokers.',
      ),
      LegalSection(
        heading: 'Open principles',
        body:
            '• Privacy by default — every phone number stays masked.\n'
            '• No sale of personal data.\n'
            '• Clear, time-bound data retention.\n'
            '• A real human grievance officer, not a chatbot.',
      ),
    ],
  );

  // ─── Contact ───────────────────────────────────────────────────────────
  static const contactUs = LegalDocument(
    title: 'Contact Us',
    lastUpdated: '07 July 2026',
    intro: 'We respond to every message. Pick the channel that fits.',
    showFooter: false,
    sections: [
      LegalSection(
        heading: 'Customer support',
        body:
            'Email: $supportEmail\n'
            'Phone: $supportPhone\n'
            'Hours: 9 to 9',
      ),
      LegalSection(
        heading: 'Postal Address',
        body: '$companyName\n$officeAddress',
      ),
    ],
  );
}
