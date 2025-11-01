# 🏥 Nurse Tracking App

A comprehensive Flutter application designed for hospitals to track and manage home care nurses. This app provides real-time GPS tracking, scheduling management, and employee information systems to ensure efficient healthcare delivery.

## 📱 Features

### 🔐 Authentication & Security
- Secure login/signup system with Supabase Auth
- Row Level Security (RLS) for data protection
- Employee profile management

### 👩‍⚕️ Employee Management
- Complete employee profiles with personal and work information
- Profile photo support
- Department and position tracking
- Hire date and status management

### 📅 Schedule Management
- View daily and weekly schedules
- Reschedule appointments with date/time picker
- Patient information integration
- Service type categorization
- Real-time status updates

### 📍 GPS Time Tracking
- Location-based clock in/out system
- Real-time GPS coordinate capture
- Address geocoding for readable locations
- Automatic work hour calculations
- Time log history and reporting

### 🏠 Patient Management
- Patient profiles with medical notes
- Emergency contact information
- GPS coordinates for patient locations
- Address management

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- Android Studio / VS Code
- Supabase account

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/nurse-tracking-app.git
   cd nurse-tracking-app
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Supabase**
   - Create a new project at [supabase.com](https://supabase.com)
   - Copy your project URL and anon key
   - Update `lib/main.dart` with your credentials:
   
   ```dart
   await Supabase.initialize(
     url: 'YOUR_SUPABASE_URL',
     anonKey: 'YOUR_SUPABASE_ANON_KEY',
   );
   ```

4. **Set up the database**
   - Go to your Supabase SQL Editor
   - Run the SQL scripts in order:
     - `scripts/01-create-tables.sql`
     - `scripts/02-seed-data.sql`

5. **Configure permissions**
   - For Android: Location permissions are already configured in `android/app/src/main/AndroidManifest.xml`
   - For iOS: Add location permissions to `ios/Runner/Info.plist`

6. **Run the app**
   ```bash
   flutter run
   ```

## 🏗️ Project Structure

```
lib/
├── main.dart                 # App entry point and Supabase initialization
├── models/                   # Data models
│   ├── employee.dart
│   ├── patient.dart
│   ├── schedule.dart
│   └── time_log.dart
└── pages/                    # UI screens
    ├── splash_page.dart      # Loading screen
    ├── login_page.dart       # Authentication
    ├── employee_setup_page.dart # Profile setup
    ├── dashboard_page.dart   # Main dashboard
    ├── employee_info_page.dart # Profile management
    ├── schedule_page.dart    # Schedule viewing/management
    └── time_tracking_page.dart # GPS time tracking

scripts/
├── 01-create-tables.sql      # Database schema
└── 02-seed-data.sql         # Sample data
```

## 🛠️ Technologies Used

- **Frontend**: Flutter & Dart
- **Backend**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Database**: PostgreSQL with Row Level Security
- **Location Services**: Geolocator & Geocoding
- **State Management**: StatefulWidget
- **UI Components**: Material Design 3

## 📊 Database Schema

### Tables
- **employees**: Store nurse profiles and information
- **patients**: Patient details with GPS coordinates
- **schedules**: Appointment scheduling system
- **time_logs**: GPS-tracked time entries with location data

### Security
- Row Level Security (RLS) enabled on all tables
- Users can only access their own data
- Secure authentication with Supabase

## 🔧 Configuration

### Environment Variables
Update the following in `lib/main.dart`:
- `SUPABASE_URL`: Your Supabase project URL
- `SUPABASE_ANON_KEY`: Your Supabase anon key

### Permissions
The app requires the following permissions:
- **Location**: For GPS tracking during clock in/out
- **Internet**: For database connectivity

## 📱 Usage

1. **Sign Up/Login**: Create an account or sign in
2. **Complete Profile**: Fill in employee information
3. **View Dashboard**: Access all app features from the main dashboard
4. **Check Schedule**: View today's appointments and upcoming visits
5. **Clock In/Out**: Use GPS-based time tracking at patient locations
6. **Manage Profile**: Update personal and work information

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/nurse-tracking-app/issues) page
2. Create a new issue with detailed information
3. Contact the development team

## 🔮 Future Enhancements

- [ ] Push notifications for schedule reminders
- [ ] Offline support for poor connectivity areas
- [ ] Admin dashboard for hospital managers
- [ ] Advanced reporting and analytics
- [ ] Integration with hospital management systems
- [ ] Multi-language support
- [ ] Dark mode theme


## 🙏 Acknowledgments

- [Supabase](https://supabase.com) for the excellent backend-as-a-service
- [Flutter](https://flutter.dev) team for the amazing framework
- Healthcare workers who inspired this project

---

**Made with ❤️ for healthcare professionals**
```

This README file provides:

1. **Clear project description** with emoji icons for visual appeal
2. **Comprehensive feature list** organized by category
3. **Step-by-step installation guide** with code examples
4. **Project structure** showing file organization
5. **Technology stack** information
6. **Database schema** overview
7. **Configuration instructions** for Supabase setup
8. **Usage guidelines** for end users
9. **Contributing guidelines** for developers
10. **Future enhancement** roadmap
11. **Professional formatting** with proper markdown syntax

You can customize this README by:
- Replacing `yourusername` with your actual GitHub username
- Adding actual screenshots when available
- Updating the license section based on your preference
- Adding any specific installation requirements for your environment
- Including additional acknowledgments or credits

This README will make your project look professional and help other developers understand and contribute to your nurse tracking application!
