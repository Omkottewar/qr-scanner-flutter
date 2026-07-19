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
  });

  final String title;
  final String lastUpdated;
  final String intro;
  final List<LegalSection> sections;
}

abstract final class LegalContent {
  // Real CP Network Private Limited values, matching the Privacy Policy PDF.
  static const String companyName = 'CP Network Private Limited';
  static const String officeAddress = 'Bhagwan Nagar, Nagpur, Maharashtra, India';
  static const String supportEmail = 'support@cpnetwork.in';
  static const String legalEmail = 'support@cpnetwork.in';
  static const String billingEmail = 'support@cpnetwork.in';
  static const String grievanceEmail = 'grievance@cpnetwork.in';
  static const String grievanceOfficer = 'Grievance Redressal Officer';
  static const String supportPhone = '+91-9960049208';
  static const String websiteUrl = 'www.qr4emergency.com';

  // ─── Privacy Policy ─────────────────────────────────────────────────────
  // Source: CP Network Private Limited official Privacy Policy document
  // (QR4Emergency_Privacy_Policy.pdf), effective 25 June 2026.
  static const privacyPolicy = LegalDocument(
    title: 'Privacy Policy',
    lastUpdated: '07 July 2026',
    intro:
        'QR 4 emergency is a QR Code Vehicle Emergency Contact & Smart '
        'Parking Solution operated by CP Network Private Limited.\n\n'
        'Head Office: Bhagwan Nagar, Nagpur, Maharashtra, India\n'
        'Phone: +91-9960049208\n'
        'Email: support@cpnetwork.in\n'
        'Effective Date: 25 June 2026',
    sections: [
      LegalSection(
        heading: '1. Introduction & Scope',
        body:
            'Welcome to QR 4 emergency (the "App", "Service", "Platform"), '
            'a QR code-based vehicle emergency contact, wrong-parking '
            'resolution, and smart parking management application operated '
            'by CP Network Private Limited (the "Company", "we", "us", or '
            '"our").\n\n'
            'We are committed to protecting your personal data with the '
            'highest standards of privacy, security, and transparency in '
            'accordance with the Digital Personal Data Protection Act, '
            '2023 ("DPDP Act"), the Information Technology Act, 2000, and '
            'all applicable rules and regulations.\n\n'
            'This Privacy Policy explains:\n'
            '   • What personal data we collect and why\n'
            '   • How we use, share, store, and protect it\n'
            '   • Your rights under Indian law and how to exercise them\n'
            '   • Our grievance redressal mechanism\n\n'
            'Scope: This Policy applies to all users of the QR 4 emergency '
            'mobile application (Android & iOS) and any associated web '
            'services, including:\n'
            '   • Vehicle Owners / Registrants who create accounts and '
            'affix QR codes/stickers to their vehicles (cars, bikes, etc.)\n'
            '   • Users who scan QR codes ("Scanners") to contact vehicle '
            'owners for emergencies, wrong parking, accidents, or other '
            'legitimate purposes\n\n'
            'By registering, logging in, affixing a QR code, or using any '
            'feature of QR 4 emergency, you consent to the collection and '
            'processing of your personal data as described in this Policy.',
      ),
      LegalSection(
        heading: '2. Information We Collect',
        body:
            'We follow the principles of data minimisation and purpose '
            'limitation. We collect only the data strictly necessary to '
            'deliver and improve the Service.\n\n'
            '2.1 Data You Provide Directly:\n\n'
            '• Registration & Account Data — Full name, mobile phone '
            'number (mandatory for OTP verification and communication '
            'routing), email address (optional), profile photo (optional).\n\n'
            '• Vehicle Data — Vehicle registration number (RC number), '
            'make, model, colour, and optional vehicle photographs (for '
            'profile/verification).\n\n'
            '• QR Linkage Data — Information linking your physical QR '
            'sticker/code to your vehicle and registered mobile number.\n\n'
            '• Emergency & Additional Contacts — Names and phone numbers '
            'of emergency contacts you voluntarily provide.\n\n'
            '• Communication Preferences & Settings — Your choices '
            'regarding contactability (e.g., parking notifications only, '
            'emergency/SOS only, quiet hours, do-not-disturb).\n\n'
            '• User-Generated Content — Photographs, descriptions, or '
            'reports you upload when notifying a vehicle owner about wrong '
            'parking, an incident, or emergency.\n\n'
            '• Support & Feedback Data — Information you provide when '
            'contacting customer support, submitting feedback, or '
            'responding to surveys.\n\n'
            '2.2 Data Collected Automatically (with Permissions):\n\n'
            '• Device & Technical Information — Device model, operating '
            'system, app version, unique device identifiers (for security '
            'and anti-fraud), IP address, crash logs, and performance '
            'data.\n\n'
            '• Usage Data — Features accessed, QR scans performed '
            '(timestamp, QR identifier), session duration, and interaction '
            'patterns (processed in aggregated or anonymised form where '
            'possible).\n\n'
            '• Location Data (optional, with explicit consent) — Precise '
            'or approximate location at the time of scanning a QR code or '
            'when you enable location-based features. You can disable '
            'location permission anytime in your device settings.\n\n'
            '• Camera & Photo Library Access (with explicit permission) — '
            'Required to scan QR codes and optionally capture/upload '
            'photographs of parking situations or your vehicle.\n\n'
            'We do NOT collect sensitive personal data (biometrics, health '
            'information, financial details, etc.) unless explicitly '
            'required for a future feature and with separate clear consent.',
      ),
      LegalSection(
        heading: '3. How We Use Your Information',
        body:
            'We process your personal data only for the following specific '
            'and legitimate purposes, with the legal basis under the DPDP '
            'Act noted alongside each:\n\n'
            '• Account creation, QR linkage & core service delivery '
            '— Contract performance + Consent. We register you, link your '
            'QR to your vehicle, and enable scanners to reach you '
            'privately.\n\n'
            '• Facilitate masked/private communication between users '
            '— Consent + Legitimate Interest. We route masked calls and '
            'SMS so your real number is not exposed to scanners.\n\n'
            '• Send transactional & service notifications '
            '— Contract + Legitimate Interest. We send OTPs, scan alerts '
            'to vehicle owners, and delivery confirmations.\n\n'
            '• Safety, fraud prevention & anti-harassment '
            '— Legitimate Interest + Legal Obligation. We detect misuse, '
            'block abusive users, and maintain logs for disputes.\n\n'
            '• Service improvement & analytics '
            '— Legitimate Interest. We analyse aggregated usage to fix '
            'bugs, add features, and optimise performance.\n\n'
            '• Legal compliance & safety '
            '— Legal Obligation. We respond to valid government and '
            'law-enforcement requests and court orders.\n\n'
            'We provide just-in-time notices inside the App at the point '
            'of data collection so you always know what data is being '
            'collected and why. We do NOT use your data for targeted '
            'behavioural advertising or sell it to data brokers.',
      ),
      LegalSection(
        heading: '4. How We Share Your Information',
        body:
            'We do NOT sell, rent, or commercially exploit your personal '
            'data. We share data only when necessary and under strict '
            'contractual safeguards (Data Processing Agreements).\n\n'
            'Key Recipients:\n\n'
            '• Licensed Indian Telecom / CPaaS Partners (Call Masking & '
            'SMS Providers) — We share only the minimum data required '
            '(your registered phone number in masked/virtual form and the '
            "scanner's phone number temporarily) to enable private, masked "
            'voice calls or SMS between you and the person who scanned '
            'your QR. These partners act as data processors. This is the '
            'core privacy feature of QR 4 emergency — scanners never '
            'receive or store your real phone number.\n\n'
            '• Cloud Hosting & Backend Service Providers — Reputable '
            'providers, with preference for India-based infrastructure.\n\n'
            '• Legal & Government Authorities — Only when required by law '
            'or to protect life or safety.',
      ),
      LegalSection(
        heading: '5. Data Retention',
        body:
            '• Account, Vehicle & QR Linkage Data — Retained while your '
            'account is active. After a deletion request or 2–3 years of '
            'inactivity, data is deleted or anonymised.\n\n'
            '• Communication & Scan Logs (including masked call '
            'metadata) — 6 to 12 months for dispute resolution and '
            'telecom compliance.\n\n'
            '• User-Uploaded Photos / Content — Deleted once the related '
            'communication is resolved or upon your verified request.\n\n'
            '• Technical & Analytics Data — Raw data deleted within 90 '
            'days; aggregated data retained longer for service '
            'improvement.',
      ),
      LegalSection(
        heading: '6. Your Rights Under the DPDP Act, 2023',
        body:
            'As a Data Principal, you have the following rights:\n\n'
            '   • Right to access your personal data and details of '
            'processing\n'
            '   • Right to correction of inaccurate or incomplete data\n'
            '   • Right to erasure / deletion of your personal data\n'
            '   • Right to withdraw consent (as easy as giving consent)\n'
            '   • Right to grievance redressal with us\n'
            '   • Right to nominate a person to exercise rights on your '
            'behalf\n'
            '   • Right to data portability (where technically feasible)\n\n'
            'How to Exercise Your Rights:\n\n'
            '   1. In-App (fastest): Profile / Settings → Privacy / Data '
            'Rights section\n'
            '   2. Email: privacy@cpnetwork.in or support@cpnetwork.in\n'
            '   3. Phone / WhatsApp: +91-9960049208',
      ),
      LegalSection(
        heading: '7. Security Measures',
        body:
            'We implement reasonable and appropriate security safeguards '
            'including encryption in transit (TLS) and at rest (AES-256), '
            'strict access controls, regular security assessments, and '
            'employee training. While we take all reasonable steps, no '
            'system is 100% secure. In case of a qualifying personal data '
            'breach, we will notify affected users and the Data Protection '
            'Board as required under DPDP Rules.',
      ),
      LegalSection(
        heading: "8. Children's Privacy",
        body:
            'QR 4 emergency is intended for adults (18+ years). We do not '
            'knowingly collect personal data from children under 18.',
      ),
      LegalSection(
        heading: '9. International Data Transfers',
        body:
            'We primarily process and store personal data within India. '
            'Any transfers outside India will have adequate safeguards and '
            'will be disclosed in updates to this Policy.',
      ),
      LegalSection(
        heading: '10. Cookies, SDKs & Tracking',
        body:
            'The App uses essential local storage and analytics SDKs '
            '(aggregated/anonymised where possible). We do not use '
            'third-party advertising networks or cross-app tracking for '
            'behavioural advertising.',
      ),
      LegalSection(
        heading: '11. Changes to This Privacy Policy',
        body:
            'We may update this Policy. Material changes will be notified '
            'via in-app banner, email, or updated "Last Updated" date. '
            'Continued use constitutes acceptance.',
      ),
      LegalSection(
        heading: '12. Grievance Redressal Mechanism',
        body:
            'Grievance Redressal Officer\n'
            'CP Network Private Limited\n'
            'Bhagwan Nagar, Nagpur, Maharashtra\n'
            'Phone: +91-9960049208\n'
            'Email: grievance@cpnetwork.in\n\n'
            'We aim to resolve grievances within DPDP timelines (typically '
            '15–30 days).',
      ),
      LegalSection(
        heading: '13. Governing Law & Jurisdiction',
        body:
            'This Policy is governed by the laws of India. Disputes are '
            'subject to the exclusive jurisdiction of competent courts in '
            'Nagpur, Maharashtra, India, without prejudice to your rights '
            'under the DPDP Act.',
      ),
      LegalSection(
        heading: '14. Contact Us',
        body:
            'CP Network Private Limited\n'
            'Head Office: Bhagwan Nagar, Nagpur, Maharashtra, India\n'
            'Phone: +91-9960049208\n'
            'Email: support@cpnetwork.in\n'
            'Grievance: grievance@cpnetwork.in\n\n'
            'Thank you for trusting QR 4 emergency. We built this platform '
            'to make roads safer, resolve parking issues responsibly, and '
            'protect your privacy at every step.',
      ),
    ],
  );

  // ─── Terms & Conditions ────────────────────────────────────────────────
  static const termsAndConditions = LegalDocument(
    title: 'Terms & Conditions',
    lastUpdated: '07 July 2026',
    intro:
        'These Terms govern your use of QR 4 Emergency, operated by '
        '$companyName. By creating an account, activating a QR, or using '
        'the Service in any way, you agree to be bound by these Terms. If '
        'you do not agree, do not use the Service.',
    sections: [
      LegalSection(
        heading: '1. Eligibility',
        body:
            'You must be at least 18 years old and capable of forming a '
            'binding contract under Indian law. If you create a QR for a '
            'vehicle you do not personally own, you confirm you have the '
            'owner\'s written authorisation to register that vehicle.',
      ),
      LegalSection(
        heading: '2. Nature of the Service',
        body:
            'QR 4 Emergency provides a QR-code-based bridge that allows a '
            'bystander who scans your QR to reach the emergency contacts you '
            'have nominated, through a masked telephone bridge. The Service '
            'is informational and connectivity-only. It is NOT a substitute '
            'for emergency services. In any life-threatening situation you '
            'must dial 112 (national emergency), 102 (ambulance), 100 '
            '(police), or 101 (fire) directly.',
      ),
      LegalSection(
        heading: '3. Your account',
        body:
            '• Provide accurate, current, and complete information when '
            'creating your account.\n'
            '• Keep your registered mobile number and emergency contacts '
            'current. Out-of-date contacts may render the Service ineffective '
            'in an emergency.\n'
            '• Maintain the confidentiality of your OTP, biometric '
            'credentials, and device.\n'
            '• Notify us immediately of any unauthorised use of your '
            'account.',
      ),
      LegalSection(
        heading: '4. Fees and validity',
        body:
            '4.1 Plan: QR 4 Emergency at ₹549 (₹499 platform fee + ₹50 '
            'shipping, inclusive of applicable taxes) per registered QR — '
            'a one-time payment, no annual renewal, no recurring charges.\n'
            '4.2 Payment: Processed through Razorpay. By purchasing you '
            'authorise the one-time charge.\n'
            '4.3 Validity: A QR remains active for the lifetime of your '
            'account. We may retire or discontinue individual QRs only '
            'for a breach of these Terms.\n'
            '4.4 Multiple QRs: You may register multiple QRs for multiple '
            'vehicles. Each is billed separately at the same one-time '
            'fee.',
      ),
      LegalSection(
        heading: '5. Refund and cancellation',
        body:
            '5.1 You may request a full refund within 7 days of payment '
            'ONLY IF the physical QR sticker has not yet been dispatched '
            'and the digital QR has not been activated, scanned, or used '
            'to place a bridged call.\n'
            '5.2 If the physical QR sticker has already been dispatched at '
            'the time of your refund request, a non-refundable operational '
            'fee of INR 150 will be deducted to cover the cost of QR '
            'generation, activation, printing, packaging, and shipping. '
            'The balance will be refunded to your original payment method.\n'
            '5.3 After the digital QR has been activated, scanned, or used '
            'to place a bridged call — or after 7 days from payment, '
            'whichever is earliest — the subscription is fully '
            'non-refundable, except in the case of demonstrable failure of '
            'the Service attributable to us.\n'
            '5.4 Additional / replacement QRs provided to you at your '
            'request are treated as fulfilled services and are '
            'non-refundable from the moment of dispatch, regardless of the '
            'primary subscription\'s refund status.\n'
            '5.5 Procedure: email $billingEmail with your registered '
            'mobile number and order ID. We will acknowledge within 2 '
            'working days and process approved refunds within 7-14 working '
            'days to the original payment method. Bank processing time is '
            'not included in this window.\n'
            '5.6 You may close your account at any time from the Profile '
            'tab. Closure does not entitle you to a refund of unused '
            'subscription time.',
      ),
      LegalSection(
        heading: '6. Manual / referral QRs',
        body:
            'QRs distributed offline and activated via a referral code are '
            'governed by these same Terms from the moment of activation.',
      ),
      LegalSection(
        heading: '7. Acceptable use',
        body:
            'You agree not to:\n'
            '   • Register a vehicle you do not own or do not have '
            'authorisation to register\n'
            '   • Use the Service to harass, defraud, impersonate, or stalk '
            'any person\n'
            '   • Probe, scan, or test our systems for vulnerabilities '
            'except under a written authorisation from us\n'
            '   • Reverse-engineer, decompile, or extract our source code or '
            'database\n'
            '   • Use automated means, scrapers, or bots to access the '
            'Service\n'
            '   • Upload information that infringes any third-party right or '
            'violates Indian law\n'
            '   • Misuse the masked-calling feature to make nuisance calls\n\n'
            'Violation may result in suspension or termination without '
            'refund.',
      ),
      LegalSection(
        heading: '8. Intellectual property',
        body:
            'All trademarks, logos, designs, source code, and the QR 4'
            'Emergency name and brand are owned by $companyName. You receive '
            'a limited, revocable, non-transferable, non-exclusive licence '
            'to use the Service for your personal, non-commercial use only.',
      ),
      LegalSection(
        heading: '9. Disclaimer of warranties',
        body:
            'THE SERVICE IS PROVIDED "AS IS" AND "AS AVAILABLE". TO THE '
            'MAXIMUM EXTENT PERMITTED BY INDIAN LAW, WE DISCLAIM ALL '
            'WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WARRANTIES OF '
            'MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND '
            'NON-INFRINGEMENT.\n\n'
            'We do NOT guarantee that:\n'
            '   • Calls will connect\n'
            '   • Your nominated contacts will answer\n'
            '   • Emergency responders will arrive in any particular time\n'
            '   • The Service will be available at any given moment\n'
            '   • The mobile network or device will allow a call at the time '
            'of need',
      ),
      LegalSection(
        heading: '10. Limitation of liability',
        body:
            'To the maximum extent permitted by Indian law, our total '
            'aggregate liability arising out of or in connection with the '
            'Service shall not exceed the amount you actually paid us in the '
            '12 months immediately preceding the event giving rise to the '
            'claim. We shall not be liable for any indirect, consequential, '
            'incidental, exemplary, or punitive damages, including loss of '
            'profit, loss of data, personal injury, or death, arising from '
            'or relating to your use of, or inability to use, the Service.',
      ),
      LegalSection(
        heading: '11. Indemnity',
        body:
            'You agree to indemnify, defend, and hold harmless $companyName, '
            'its directors, officers, employees, and agents from and against '
            'any claim, demand, damage, loss, liability, or expense '
            '(including reasonable attorneys\' fees) arising out of (a) your '
            'breach of these Terms, (b) your misuse of the Service, (c) your '
            'violation of any law or third-party right, or (d) the content '
            'you submit.',
      ),
      LegalSection(
        heading: '12. Suspension and termination',
        body:
            'We may suspend or terminate your account or your access to the '
            'Service at any time for breach of these Terms, suspected fraud, '
            'or as required by law. You may close your account at any time '
            'from the Profile tab; data retention follows our Privacy '
            'Policy.',
      ),
      LegalSection(
        heading: '12A. Deleting a QR',
        body:
            'You may delete any of your QRs at any time from the History '
            'tab. Deleting a QR is permanent: it removes the QR record, '
            'the emergency contacts associated with that QR, all alert '
            'scans, all call logs, and all caller-activity/block entries '
            'tied to that QR from our systems. Your account itself is not '
            'deleted; any other QRs you own remain active. Once deleted, '
            'the physical sticker will no longer route calls, and the '
            'data cannot be recovered.',
      ),
      LegalSection(
        heading: '13. Changes to these Terms',
        body:
            'We may amend these Terms from time to time. Material changes '
            'will be notified in-app or by email at least 7 days before they '
            'take effect. Continued use of the Service after the effective '
            'date constitutes acceptance.',
      ),
      LegalSection(
        heading: '14. Governing law and dispute resolution',
        body:
            'These Terms are governed by and construed in accordance with '
            'the laws of India. Subject to applicable consumer-protection '
            'statutes, the courts at Nagpur, Maharashtra shall have exclusive '
            'jurisdiction over any dispute arising out of or in connection '
            'with these Terms or the Service.',
      ),
      LegalSection(
        heading: '15. Contact',
        body:
            'Support: $supportEmail\n'
            'Billing: $billingEmail\n'
            'Legal notices: $legalEmail',
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
      LegalSection(
        heading: 'Medical information',
        body:
            'Any blood-group or medical information you provide is shown to '
            'a bystander or paramedic on a best-effort basis. We do not '
            'verify medical information. Always carry your own primary '
            'medical identification (ID card, MedicAlert bracelet) — do not '
            'rely solely on our app for first-responder information.',
      ),
    ],
  );

  // ─── About ─────────────────────────────────────────────────────────────
  static const about = LegalDocument(
    title: 'About QR 4 Emergency',
    lastUpdated: '07 July 2026',
    intro:
        'QR 4 Emergency is a connectivity tool for vehicle owners in India.',
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
            '$companyName is an independent Indian company. We are not '
            'affiliated with any government emergency service, insurance '
            'company, or vehicle manufacturer. We are funded entirely by '
            'our subscribers — we do not sell or share your data with '
            'advertisers or data brokers.',
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

  // ─── Refund & Cancellation ─────────────────────────────────────────────
  static const refundPolicy = LegalDocument(
    title: 'Refund & Cancellation',
    lastUpdated: '07 July 2026',
    intro:
        'This policy is in addition to, and forms part of, our Terms & '
        'Conditions. In case of conflict, the Terms govern.',
    sections: [
      LegalSection(
        heading: 'Cooling-off period (before dispatch)',
        body:
            'You may request a FULL refund within 7 days of payment ONLY '
            'IF (a) the physical QR sticker has not yet been dispatched, '
            '(b) the digital QR has not been activated, (c) it has not '
            'been scanned, and (d) it has not been used to bridge any call.',
      ),
      LegalSection(
        heading: 'After dispatch, before activation',
        body:
            'If the physical QR sticker has already been dispatched at the '
            'time of your refund request (but has not been activated / '
            'scanned / used to bridge a call), a non-refundable '
            'operational fee of INR 150 will be deducted to cover the '
            'cost of QR generation, activation, printing, packaging, and '
            'shipping. The remaining amount will be refunded to your '
            'original payment method.',
      ),
      LegalSection(
        heading: 'After activation',
        body:
            'Once a QR is activated, scanned, or used to bridge a call, the '
            'subscription is FULLY non-refundable for the 365-day validity '
            'period, except in the case of demonstrable service failure '
            'attributable to us. Closing your account does not entitle you '
            'to a refund of unused time.',
      ),
      LegalSection(
        heading: 'Additional / replacement QRs',
        body:
            'Extra QRs provided at your request are treated as fulfilled '
            'services from the moment they are dispatched and are '
            'non-refundable, independent of the primary subscription\'s '
            'refund status.',
      ),
      LegalSection(
        heading: 'How to request a refund',
        body:
            '1. Email $billingEmail from your registered email address.\n'
            '2. Include your registered mobile number, Razorpay order ID, '
            'and the reason for the refund.\n'
            '3. We will acknowledge within 2 working days.\n'
            '4. Approved refunds are processed within 7-14 working days to '
            'the original payment method. Bank processing time is not '
            'included in this window.',
      ),
      LegalSection(
        heading: 'Cancellation by us',
        body:
            'If we cancel your subscription for breach of our Terms, no '
            'refund will be issued. If we cancel for any other reason '
            '(including service discontinuation), we will refund the unused '
            'pro-rata portion.',
      ),
      LegalSection(
        heading: 'Chargebacks',
        body:
            'Please contact us before initiating a chargeback with your '
            'bank. Unjustified chargebacks may result in suspension of your '
            'account and forfeiture of remaining subscription.',
      ),
    ],
  );

  // ─── Contact ───────────────────────────────────────────────────────────
  static const contactUs = LegalDocument(
    title: 'Contact Us',
    lastUpdated: '07 July 2026',
    intro: 'We respond to every message. Pick the channel that fits.',
    sections: [
      LegalSection(
        heading: 'Customer support',
        body:
            'Email: $supportEmail\n'
            'Phone: $supportPhone\n'
            'Hours: 09:00 to 17:00 IST, Monday to Saturday',
      ),
      LegalSection(
        heading: 'Billing and refunds',
        body: 'Email: $billingEmail',
      ),
      LegalSection(
        heading: 'Legal notices',
        body:
            'Email: $legalEmail\n'
            'For service of legal process, send to the postal address '
            'below.',
      ),
      LegalSection(
        heading: 'Grievance Officer',
        body:
            'For complaints under the DPDP Act 2023 and the IT Act 2000:\n\n'
            '$grievanceOfficer\n'
            'Email: $grievanceEmail\n'
            'Postal: $companyName, $officeAddress',
      ),
      LegalSection(
        heading: 'Postal address',
        body:
            '$companyName\n'
            '$officeAddress\n'
            'India',
      ),
    ],
  );
}
