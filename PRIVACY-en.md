# Privacy Policy

**Application:** Zev Charger (`mn.zevcharger.app`)
**Data controller:** ZEVTABS LLC
**Platform:** https://eplug.mn
**Effective date:** 20 August 2026
**Last updated:** 20 August 2026

---

## 1. Introduction

ZEVTABS LLC ("we", "us", "the Company") develops and operates the Zev Charger mobile application for electric vehicle charging stations, together with the eplug.mn platform.

This policy explains what information we collect when you use the Zev Charger app, for what purposes we process it, who we share it with, how we protect it, and what rights you have.

By downloading and using the application you accept the terms of this policy. If you do not agree with them, please do not use the application.

## 2. About the data controller

| | |
|---|---|
| Legal entity | ZEVTABS LLC |
| Address | Khan-Uul district, Ulaanbaatar, Mongolia |
| Website | https://eplug.mn |
| Privacy contact | [privacy@zevtabs.mn] |
| Phone | [+976 XXXX XXXX] |

## 3. What information we collect

### 3.1. Location data (GPS)

The application requests access to your device location for the following purposes:

- to show nearby charging stations on the map;
- to calculate the distance and direction from you to a station;
- to follow your movement along a route in real time (navigation).

**Important:** Location data is accessed only while the application is **open and in use**. We do not collect your location when the application is closed or running in the background. We also do not store your location history on our servers.

You can revoke location sharing at any time in your device settings. In that case the map and the station list will still work, without identifying your position.

### 3.2. Account information

If you create a user account on the platform, we process:

- your email address or phone number;
- your name (if you provide it);
- your login password — **only as an irreversible hash (bcrypt)**. We do not store your password in plain text and cannot read it;
- the time you last signed in.

### 3.3. Charging session data

If you use one of our charging stations, the following is recorded:

- the charging card/tag identifier (idTag) and the holder name and email associated with it;
- the station and connector identifier;
- the start and end time of the charging session;
- energy consumed (kWh), the applicable tariff and the amount charged;
- technical measurements taken during the session — such as power (kW), battery state of charge (SoC) and meter readings;
- the reason the session ended.

### 3.4. Technical and log data

- server request logs (IP address, time of the request, request type);
- logs of OCPP protocol messages exchanged with the charging station (for technical diagnostics and audit purposes);
- basic device information required for the application to run (operating system version, application version).

### 3.5. What we do not collect

We do **not** collect:

- your contacts, photos, files, messages or call history;
- your bank card or account numbers (if payment services are introduced, payments will be processed exclusively through a licensed payment provider and we will not store card numbers);
- biometric data;
- the application contains no advertising networks and no third-party analytics or tracking SDKs.

## 4. Purposes of processing

We use the information we collect only in order to:

1. provide the service of showing charging station locations and calculating directions;
2. identify you, sign you in and verify your permissions;
3. authorise use of a charging station and start and stop charging sessions;
4. calculate charges for the energy consumed and issue payment records;
5. detect and fix technical faults and resolve service interruptions;
6. maintain network security and detect unauthorised access;
7. improve service quality (in aggregate form, without identifying individuals);
8. comply with our obligations under the laws of Mongolia.

We do **not sell your information and do not share it with third parties for advertising purposes**.

## 5. Legal basis for processing

We process personal data in accordance with the Law of Mongolia on Personal Data Protection and other applicable legislation, on the following bases:

- **your consent** — for location access and account creation;
- **performance of a contract** — to provide charging services and calculate payment;
- **legal obligation** — accounting and tax record-keeping;
- **legitimate interest** — network security and detection of unlawful use.

## 6. Sharing with third parties

### 6.1. Third-party services the application contacts directly

| Service | What it receives | Purpose |
|---|---|---|
| OpenStreetMap (openstreetmap.org) | your device IP address, the map area being viewed | downloading map tiles |
| OSRM (router.project-osrm.org) | the start and end coordinates of your route | route calculation |
| Google Maps (only if you tap through) | destination coordinates | opening external navigation |
| Google Play (Google LLC) | information required to download and update the app | store services |

Each of these services is governed by its own privacy policy. We draw your attention in particular to the fact that, in order to calculate a route, your origin and destination coordinates are transmitted to the OSRM service.

### 6.2. Other cases

We disclose your information to others only:

- with your specific, prior consent;
- to the operator that owns a charging station — limited to the information needed for the charging session and payment at that station;
- to law enforcement, courts or other competent authorities, upon a written official request made in accordance with the procedure established by law;
- to contractors that provide services on our behalf (server hosting, payment processing) — under a confidentiality agreement and only to the extent necessary.

## 7. Retention periods

| Type of data | Retention period |
|---|---|
| Location data | Not stored on our servers. Only on the device, while the application is running |
| Account information | For as long as the account is active. Deleted within 30 days of a deletion request |
| Charging and payment records | For the period required by accounting and tax legislation |
| OCPP protocol technical logs | 30 days, then deleted automatically |
| Server access logs | Not retained longer than 90 days |

Data whose retention period has expired is deleted or rendered incapable of identifying the individual concerned.

## 8. Security measures

To protect your information we apply the following measures:

- all network connections are protected with **TLS 1.2 / TLS 1.3** encryption (https, wss);
- passwords are stored irreversibly hashed with **bcrypt**;
- access is limited by time-limited tokens (JWT) and role-based permissions;
- login requests are rate-limited to frustrate automated attacks;
- connections to charging stations use OCPP security profiles (authentication, TLS, mutual certificates);
- access to data is granted only where required by a job function, at the minimum necessary level.

Please note, however, that no method of transmission over the internet or of electronic storage can be guaranteed to be 100% secure. In the event of a data breach we will notify the competent authority within the period required by law and inform affected users.

## 9. Your rights

Under the Law of Mongolia on Personal Data Protection you have the right to:

1. **be informed** — to request confirmation of what data we process about you and to obtain a copy;
2. **rectification** — to have incorrect or incomplete data corrected;
3. **erasure** — to have your data deleted and your account closed;
4. **restriction and objection** — to have specific processing stopped;
5. **withdraw consent** — to withdraw consent previously given at any time (this does not affect the lawfulness of processing carried out before withdrawal);
6. **lodge a complaint** — if you are dissatisfied with our decision, to complain to the National Human Rights Commission of Mongolia or to the competent state inspector.

To exercise your rights, contact us at [privacy@zevtabs.mn]. We will respond **within 30 days** of receiving your request. We may require additional verification in order to confirm your identity.

## 10. Deleting your account and data

To have your account and associated data deleted, send a request to [privacy@zevtabs.mn] with the subject line "Account deletion request", stating the email address or phone number registered to the account.

Once the request is verified, your account and associated data will be deleted within 30 days. Payment records that accounting and tax legislation requires us to keep will be retained until the statutory period expires.

## 11. Children's personal data

The application is not directed at persons under 18 years of age. We do not knowingly collect information from persons under 18. Where a person under 18 uses the application, the consent of a legal representative (parent or guardian) is required. If we determine that we have collected the data of a person under 18 without such consent, we will delete that data immediately.

## 12. International transfers

Our servers are located in Mongolia. However, the third-party services listed in section 6.1 (maps, routing, Google Play) may use servers located outside Mongolia. In such cases only the minimum information necessary to provide that service is transmitted.

## 13. Changes to this policy

We may update this policy in response to changes in legislation or in our services. The updated policy will be published at https://eplug.mn/privacy and within the application. Where a change materially affects your rights, we will give notice in the application and, where required, obtain your consent again.

The "Last updated" date indicates the version of the policy currently in force.

## 14. Contact

Questions, requests and complaints relating to personal data can be addressed to:

**ZEVTABS LLC**
Khan-Uul district, Ulaanbaatar, Mongolia
Email: [privacy@zevtabs.mn]
Phone: [+976 XXXX XXXX]
Website: https://eplug.mn
