# TripLanka 🚗

A travel booking prototype built with Flutter and Firebase for journeys across Sri Lanka.

Passengers can plan trips, choose vehicles, and manage bookings. Registered drivers can accept requests and update trip progress.

🌐 **[Live Demo](https://triplanka.vercel.app)**  
💻 **[Source Code](https://github.com/sevi2001/triplanka)**

## Features

### Passenger features

- Instant ride requests
- Scheduled trips with multiple stops
- Airport transfers and full-day driver bookings
- Tuk-tuk, car, van, and minibus selection
- Map-based location search and pickup selection
- Road route previews with distance and driving estimates
- Booking status filters and cancellation
- Assigned driver details
- Ratings and reviews for completed trips
- Cost-splitting calculator
- Trip details sharing
- Emergency contact information and phone app access

### Driver features

- Driver registration and approval workflow
- Available requests filtered by vehicle type
- Trip acceptance
- Assigned trip management
- Start and complete trip actions

## Technology Stack

| Technology | Purpose |
| ---------- | ------- |
| Flutter and Dart | Application interface and logic |
| Firebase Authentication | Account registration and sign-in |
| Cloud Firestore | Profiles, bookings, and trip requests |
| flutter_map and OpenStreetMap | Interactive maps |
| Nominatim | Place search |
| OSRM | Road route calculations |
| Geolocator | Current location selection |

## Booking Workflow

1. A passenger enters journey details and chooses a vehicle.
2. Confirming the booking creates a pending trip request.
3. An approved driver with a suitable vehicle accepts the request.
4. The driver starts and completes the trip.
5. The passenger can rate the completed trip.

## Run Locally

Clone the repository:

```bash
git clone https://github.com/sevi2001/triplanka.git
cd triplanka
flutter pub get
```

Configure your own Firebase project before running the application:

- Enable Email/Password authentication.
- Create a Cloud Firestore database.
- Configure Firebase for your target platforms.
- Apply the project's Firestore security rules.
- For web authentication, configure the appropriate authorized domains.

Run the web application:

```bash
flutter run -d chrome
```

Or connect an Android device and run:

```bash
flutter run
```

## Project Status

TripLanka is a portfolio prototype.

Ride requests and driver actions demonstrate the booking workflow. Payments, live driver tracking, and production fare calculations are not connected.

Route durations are driving estimates. The cost-splitting feature calculates shares without collecting payments.

## Author

**Sevindi Jayathilake**

- [GitHub](https://github.com/sevi2001)
- [Portfolio](https://sevindi-portfolio.vercel.app/)
