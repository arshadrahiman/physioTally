# PhysioTally
**Smart Patient Invoicing & Receipt Generator for Physiotherapists & Freelance Practitioners**

PhysioTally is a medical invoicing and practice management Flutter app built specifically for:
- **Freelance & Home-Visit Physiotherapists**
- **Private Physiotherapy & Rehabilitation Clinics**
- **Sports & Neuro Rehabilitation Specialists**

---

## 🌟 Key Features

### 1. Clinical Presets & Fast Billing
- **Clinical Diagnoses Chips:** Instant selection for common conditions (Cervical Spondylosis, Lumbar Disc Prolapse, Frozen Shoulder, Knee Osteoarthritis, Post-Op ACL, Stroke Rehab, etc.).
- **Intervention & Modalities:** Manual Therapy, Ultrasound (UST), IFT / TENS, Dry Needling, Gait Training, Exercise Therapy, Home Visits.
- **Session Range & Rates:** Calculate single visits or multi-session packages in real-time.
- **Payment Modes:** UPI (GPay/PhonePe), Cash, Bank Transfer, Card with Paid/Pending status tracking.

### 2. High-Trust Medical PDF Receipts
- Practitioner credentials, Council Registration Number, and Clinic Branding.
- Dynamic QR / UPI payment details on the receipt.
- Clinical advice & precautions section.
- Practitioner signature line / digital stamp.
- Instant 1-tap share via WhatsApp, email, or direct print.

### 3. Patient Receipts History & Records
- Fully offline local storage with Hive.
- Search receipts by patient name, mobile, or diagnosis.
- Revenue metrics (Total Billed, Total Collected, Pending Dues).
- Quick toggle for payment status (Paid / Pending).
- Re-share or re-print past receipts anytime.

### 4. Subscription & Quota System
- **Free Tier (Starter):** Up to 5 free patient receipts to evaluate all features, with a discreet watermark.
- **Physio Pro:**
  - Unlimited patient invoices & receipts.
  - 100% white-label (no watermarks).
  - Custom Clinic Logo & Digital Signature on every receipt.
  - Complete offline patient history & financial metrics.
  - Flexible plans: Monthly (₹199), Annual (₹1,499 - 37% off), and Lifetime Access.
  - Promo Code unlock support (e.g., code `PHYSIOPRO` or `FREELANCE` for instant evaluation).

---

## 🛠️ Architecture

```
lib/
├── core/
│   ├── constants/
│   │   └── physio_presets.dart        # Clinical diagnosis & treatment chips
│   └── theme/
│       ├── app_theme.dart             # Medical teal & slate design system
│       └── theme_provider.dart        # Dark/light mode switcher
├── modules/
│   ├── auth/                          # Therapist authentication & state
│   ├── billform/                      # Patient billing & PDF generator
│   │   ├── controller/bill_controller.dart
│   │   ├── services/pdf_invoice_service.dart
│   │   └── view/billform_screen.dart
│   ├── history/                       # Local offline receipt archive & stats
│   ├── home/                          # 3-tab BottomNavigationBar scaffold
│   ├── login/                         # Therapist credentials & practice setup
│   ├── profile/                       # Practice details, logo, signature & settings
│   └── subscription/                  # Freemium quota, paywall & pro tier
└── main.dart
```

---

## 🧪 Testing

Run automated unit and integration tests:
```bash
flutter test
```
Run static code analysis:
```bash
flutter analyze
```
