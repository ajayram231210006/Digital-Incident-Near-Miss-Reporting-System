# QA Test Checklist

Project: `Digital Incident & Near-Miss Reporting System`

Purpose: Use this checklist to validate the app before final submission, demo, or deployment.

## Test Team Setup

- [ ] Prepare at least 3 test accounts: `Reporter 1`, `Reporter 2`, `Supervisor`, and `Admin`
- [ ] Install the latest build on all testing devices/emulators
- [ ] Confirm Firebase Authentication is working
- [ ] Confirm Realtime Database is connected
- [ ] Confirm media upload is working
- [ ] Confirm notification permission is enabled on test devices
- [ ] Keep one device available for offline testing
- [ ] Decide whether testing will be done on clean data or existing data

## 1. Authentication and Login

- [ ] Sign up as `Reporter`
- [ ] Sign up as `Supervisor`
- [ ] Sign up as `Admin`
- [ ] Verify empty field validation works during sign up
- [ ] Verify invalid login credentials show proper error
- [ ] Verify password reset flow works
- [ ] Verify login fails if the user selects the wrong role
- [ ] Verify pending approval users cannot access dashboards
- [ ] Verify rejected users see the rejection state
- [ ] Verify inactive users cannot access the app
- [ ] Verify approved users land on the correct dashboard

## 2. Admin Approval Flow

- [ ] Log in as admin
- [ ] Open the `Pending` tab and verify new users appear
- [ ] Approve a reporter account
- [ ] Approve a supervisor account
- [ ] Reject one test account
- [ ] Deactivate one active user
- [ ] Restore one inactive user
- [ ] Verify approved users can log in successfully
- [ ] Verify rejected users remain blocked
- [ ] Verify inactive users remain blocked
- [ ] Verify admin statistics update correctly

## 3. Reporter Dashboard

- [ ] Log in as reporter
- [ ] Verify dashboard loads without errors
- [ ] Verify total reports count is correct
- [ ] Verify pending review count is correct
- [ ] Verify active work count is correct
- [ ] Verify resolved count is correct
- [ ] Open `My reports` from dashboard
- [ ] Open `Analytics`
- [ ] Open `Templates`
- [ ] Open `System`
- [ ] Verify notification badge appears when notifications exist
- [ ] Verify logout works correctly

## 4. New Incident Submission

- [ ] Open `New report`
- [ ] Submit a valid report with type, description, date, and location
- [ ] Verify required-field validation for empty form fields
- [ ] Submit using manual location entry
- [ ] Test `Use current location` with permission granted
- [ ] Test `Use current location` with permission denied
- [ ] Test `Use current location` with location services disabled
- [ ] Attach multiple images
- [ ] Remove one selected image before submitting
- [ ] Attach a video
- [ ] Remove selected video before submitting
- [ ] Submit report successfully
- [ ] Verify success message appears
- [ ] Verify incident is stored in the database
- [ ] Verify incident appears in reporter reports list
- [ ] Verify incident appears in supervisor reports list
- [ ] Verify report data includes correct reporter and timestamp details

## 5. Reporter Incident Detail View

- [ ] Open a submitted report as reporter
- [ ] Verify type is shown correctly
- [ ] Verify location is shown correctly
- [ ] Verify incident date is shown correctly
- [ ] Verify submission date is shown correctly
- [ ] Verify description is shown correctly
- [ ] Verify status badge is shown correctly
- [ ] Verify supervisor notes appear when available
- [ ] Verify image gallery opens correctly
- [ ] Verify image preview screen works
- [ ] Verify video section appears when video exists
- [ ] Verify video playback screen opens

## 6. Supervisor Review Flow

- [ ] Log in as supervisor
- [ ] Open a newly submitted report
- [ ] Verify report details load properly
- [ ] Change status from `open` to `active`
- [ ] Change status from `active` to `closed`
- [ ] Set severity to `low`
- [ ] Set severity to `medium`
- [ ] Set severity to `high`
- [ ] Set severity to `critical`
- [ ] Add supervisor notes
- [ ] Save changes successfully
- [ ] Verify unsaved changes warning appears on back navigation
- [ ] Verify saved status is visible to reporter
- [ ] Verify saved severity is visible to reporter
- [ ] Verify saved notes are visible to reporter

## 7. Notifications

- [ ] Submit a new report and verify supervisor receives notification
- [ ] Submit a new report and verify other reporters receive broadcast notification
- [ ] Verify the reporter who created the report does not get duplicate broadcast notification
- [ ] Update report status as supervisor and verify reporter notification is created
- [ ] Update report severity as supervisor and verify reporter notification is created
- [ ] Add supervisor notes and verify notifications are created
- [ ] Open notification viewer as reporter
- [ ] Open notification viewer as supervisor
- [ ] Verify unread count updates correctly
- [ ] Verify badge count updates correctly
- [ ] Verify opening notifications marks them as read if expected
- [ ] Verify `Mark all as read` works
- [ ] Verify deleting a notification works
- [ ] Verify tapping a notification opens the correct report
- [ ] Verify foreground notification behavior
- [ ] Verify background notification behavior
- [ ] Verify app-launch notification behavior

## 8. Offline Reporting and Sync

- [ ] Log in as reporter while online
- [ ] Close and reopen app with internet off
- [ ] Verify offline reporter session opens correctly
- [ ] Create a report while offline
- [ ] Verify offline queue count increases
- [ ] Verify offline save message appears
- [ ] Reconnect internet
- [ ] Verify offline reports sync automatically or through `Sync`
- [ ] Verify synced report appears in dashboard
- [ ] Verify synced report appears in database
- [ ] Verify synced report is not duplicated
- [ ] Repeat offline test with image attachments
- [ ] Repeat offline test with video attachment if supported
- [ ] Verify supervisor and admin do not get unintended offline dashboard access

## 9. AI Suggestions

- [ ] Submit a report while online
- [ ] Open the report in supervisor detail view
- [ ] Verify AI Suggestions section appears
- [ ] Verify pending/processing state can be seen when applicable
- [ ] Verify completed AI output appears when available
- [ ] Verify disabled state message appears if AI is unavailable
- [ ] Verify suggested severity is shown correctly
- [ ] Verify suggested category is shown correctly
- [ ] Verify AI summary is displayed
- [ ] Verify recommended actions are displayed
- [ ] Verify missing information section is displayed when available
- [ ] Apply AI suggested severity and save it

## 10. Reports, Filters, and Analytics

- [ ] Verify reporter `All reports` filter works
- [ ] Verify reporter `Open` filter works
- [ ] Verify reporter `Active` filter works
- [ ] Verify reporter `Closed` filter works
- [ ] Verify supervisor list opens successfully
- [ ] Verify supervisor status filters work
- [ ] Verify supervisor severity filters work
- [ ] Verify `Newest` sorting works
- [ ] Verify `Stale first` sorting works
- [ ] Verify dashboard counters match stored data
- [ ] Verify recent incidents section updates correctly
- [ ] Verify priority queue section updates correctly
- [ ] Verify charts/analytics load without crashing

## 11. Data Integrity and Security

- [ ] Verify each report stores `reporterUid`
- [ ] Verify each report stores `reporterEmail`
- [ ] Verify each report stores `type`
- [ ] Verify each report stores `description`
- [ ] Verify each report stores `location`
- [ ] Verify each report stores `createdAt`
- [ ] Verify each report stores `status`
- [ ] Verify approved reporters appear in the reporter role directory
- [ ] Verify approved supervisors appear in the supervisor role directory
- [ ] Verify inactive or rejected users are removed from active role directory entries
- [ ] Verify notifications are stored under the correct user IDs
- [ ] Verify duplicate notifications are not created unexpectedly
- [ ] Verify unauthorized users cannot access restricted areas

## 12. UI, Device, and Stability Checks

- [ ] Test on Android device/emulator
- [ ] Test on web if web build is used
- [ ] Test on desktop if desktop build is used
- [ ] Verify layout works on small screens
- [ ] Verify layout works on larger screens
- [ ] Verify long text does not break the UI
- [ ] Verify loading states are visible where expected
- [ ] Verify retry/error states display correctly
- [ ] Verify app restart after login works
- [ ] Verify app restart after offline queueing works
- [ ] Verify app restart after notification receipt works
- [ ] Verify there are no crashes during normal flow

## 13. Final Regression Pass

- [ ] No crash during sign up
- [ ] No crash during login
- [ ] No crash during incident submission
- [ ] No crash during supervisor review update
- [ ] No crash during offline sync
- [ ] No crash while opening notifications
- [ ] No broken navigation paths
- [ ] No role-based access issues
- [ ] No duplicate reports after sync
- [ ] No broken media preview
- [ ] No stale notification badge after notifications are read
- [ ] Demo flow works from start to finish

## Suggested Team Execution Plan

- [ ] Tester 1: Authentication + Admin approval
- [ ] Tester 2: Reporter submission + Reporter dashboard
- [ ] Tester 3: Supervisor review + Notifications
- [ ] Tester 4: Offline flow + Sync + Regression

## Test Sign-Off

- [ ] Authentication approved
- [ ] Admin flow approved
- [ ] Reporter flow approved
- [ ] Supervisor flow approved
- [ ] Notification flow approved
- [ ] Offline flow approved
- [ ] AI suggestions approved
- [ ] Analytics/reporting approved
- [ ] Final regression approved

Tested by: ____________________

Date: ____________________

Remarks: ____________________
