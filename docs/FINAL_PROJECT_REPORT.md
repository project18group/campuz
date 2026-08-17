# CHAPTER 4: SYSTEM IMPLEMENTATION AND TESTING

## 4.1 Introduction to Implementation
The implementation phase of the Campuz platform marks the transition from conceptual models and wireframes into a fully functional software ecosystem. This chapter details the technical execution of the project, outlining the development environment, the programming paradigms adopted, the configuration of the technology stack, and the testing methodologies employed to ensure software reliability and usability.

## 4.2 Development Environment & Technology Stack
To achieve a robust, scalable, and cross-platform solution, a decoupled architecture was utilized. The system is split into a client-side mobile application and a server-side backend API.

### 4.2.1 Frontend Development (Mobile Application)
The frontend of the Campuz platform was developed using **Flutter**, a UI toolkit by Google. Flutter was selected for its ability to compile natively to both iOS and Android from a single codebase (Dart), significantly reducing development overhead while maintaining native-like performance. State management was handled efficiently using modern reactive paradigms, ensuring that UI updates, such as incoming messages or file uploads, reflect instantly without aggressive polling.

### 4.2.2 Backend Development (API Architecture)
The backend infrastructure is powered by **Django**, a high-level Python web framework, coupled with the **Django REST Framework (DRF)**. This stack was chosen for its rapid development capabilities, built-in security features, and ORM (Object-Relational Mapping). 
- **Database:** **PostgreSQL** serves as the primary relational database, chosen for its advanced indexing, transaction reliability, and ability to handle complex foreign key relationships between Users, Hubs, and Messages.
- **API Paradigm:** Communication between the Flutter app and the backend occurs over stateless RESTful API endpoints secured by JSON Web Tokens (JWT).

### 4.2.3 Third-Party Services Integration
Several third-party APIs were integrated to enhance the core functionality of the platform:
- **Arkesel SMS API:** Utilized for reliable delivery of One-Time Passwords (OTPs) during user registration, as well as for the critical offline SMS fallback feature.
- **Paystack:** Integrated to handle financial transactions, specifically allowing Hub administrators to securely top-up their SMS broadcast credits.

## 4.3 Core Module Implementations
The development was modularized into specific functional components to ensure maintainability.

### 4.3.1 Authentication and Onboarding
The system relies on phone number-based authentication to lower the barrier to entry for students. When a user registers, the backend generates a secure 6-digit OTP, which is dispatched via the Arkesel SMS gateway. Upon successful verification, the backend issues an access and refresh JWT pair. The profile setup captures the student’s full name, bio, and an optional avatar, marking their account as fully verified.

### 4.3.2 Hubs (Classes) and Role Management
"Hubs" represent the core structural unit of the application (e.g., a classroom or study group). 
- Users can create Hubs, automatically assigning them the role of `Admin`. 
- Hubs have unique, randomly generated 6-character alphanumeric invite codes.
- Members join Hubs using these invite codes. The system enforces role-based access control (RBAC), ensuring that only Admins can alter Hub metadata, generate new invite codes, or purchase SMS credits.

### 4.3.3 Real-Time Messaging and Media Sharing
Within each Hub, members engage in a unified chat interface. 
- **Text & Media:** The messaging module supports rich text and media attachments. Users can upload documents (PDF, DOCX) and images. The backend dynamically serves these assets through the `MessageAttachment` models.
- **Shared Media Tracking:** A specialized `SharedMediaScreen` aggregates all files sent within a Hub, categorized neatly into Images, Documents, and Links tabs, allowing students to easily locate past resources.

### 4.3.4 Offline SMS Fallback (Broadcasts)
A defining feature of the Campuz platform is the ability for urgent messages to bypass internet limitations. When an Admin sends a message with the `send_as_sms` flag, the backend evaluates the Hub's available SMS credits. If sufficient credits exist, the message is dispatched to all Hub members via the Arkesel API, ensuring critical announcements (e.g., canceled lectures) reach students regardless of their internet connectivity status.

## 4.4 System Testing Strategy
Testing was conducted iteratively to identify defects early and ensure the platform met its functional requirements.

### 4.4.1 Unit Testing
Unit tests were written for critical backend functions. For instance, tests were implemented to verify that the OTP generation logic successfully creates unique codes and respects the 60-second cooldown period, preventing SMS gateway abuse.

### 4.4.2 Integration Testing
Integration testing focused on the data pipeline between the Flutter app and the Django API. Using tools like Postman and the Flutter debugger, endpoints such as the `HubMessageView` were tested to ensure that complex payloads (containing both text content and multipart file attachments) were parsed, saved to PostgreSQL, and returned correctly to the client.

### 4.4.3 User Acceptance Testing (UAT)
Simulated user scenarios were conducted to validate the UX. Key workflows, such as joining a Hub with an invalid invite code, attempting to upload unsupported file formats, or receiving an SMS broadcast, were tested to ensure the app displayed appropriate, user-friendly error messages and handled edge cases gracefully.

---

# CHAPTER 5: CONCLUSION AND RECOMMENDATIONS

## 5.1 Project Summary
The overarching objective of this project was to design and implement an Academic Communication Platform that addresses the systemic issues of fragmented communication, resource misplacement, and internet unreliability prevalent in university environments. Through the development of the Campuz platform, this objective was successfully met. By centralizing communication into dedicated "Hubs" and introducing an innovative SMS fallback mechanism, the platform ensures that crucial academic information is disseminated reliably and efficiently.

## 5.2 Achievements and Limitations
### 5.2.1 Achievements
- **Seamless Cross-Platform Experience:** The delivery of a fluid, responsive mobile application for both Android and iOS devices using Flutter.
- **Guaranteed Delivery:** The successful integration of the Arkesel SMS API allows critical academic announcements to reach students offline, solving a major pain point.
- **Resource Consolidation:** The implementation of the Shared Media interface automatically organizes class resources, eliminating the chaos typical of traditional messaging apps like WhatsApp.

### 5.2.2 Limitations
While the core objectives were achieved, certain limitations exist within the current iteration:
- **Real-Time WebSockets:** The current chat interface relies heavily on aggressive state updates and HTTP requests. A full-duplex WebSocket integration (via Django Channels) would reduce server overhead during high-traffic periods.
- **File Storage Scalability:** Currently, media attachments are handled by the native Django filesystem. For a large-scale deployment, this must be migrated to a dedicated cloud storage provider (e.g., AWS S3).

## 5.3 Future Work Recommendations
To further enhance the Campuz platform, the following features are recommended for future iterations:
1. **Video and Audio Conferencing:** Integrating WebRTC capabilities to allow for virtual lectures directly within the Hub interface.
2. **AI-Powered Assistance:** Implementing a chatbot or document summarization tool to help students quickly digest long PDFs or lecture notes shared in the Hub.
3. **Faculty Web Portal:** Developing a React or Vue.js web dashboard dedicated to university administrators for overseeing multiple Hubs, managing student enrollments, and analyzing engagement metrics.

## 5.4 Final Conclusion
The Campuz platform demonstrates a significant step forward in optimizing academic communication. By thoughtfully combining modern mobile development frameworks with a robust backend architecture, the project provides a tailored, secure, and highly reliable ecosystem for students and educators. The integration of offline SMS capabilities sets it apart from generic messaging applications, proving that technology can be adapted to overcome infrastructural challenges in educational environments.
