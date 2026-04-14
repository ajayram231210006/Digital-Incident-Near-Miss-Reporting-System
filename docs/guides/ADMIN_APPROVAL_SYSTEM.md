# Admin Approval System - Setup & Usage Guide

## Overview

This guide explains how the new **Admin Approval System** works in your Incident Reporting System. It controls who can access the system and what role they have (Reporter, Supervisor, or Admin).

---

## System Architecture

### User Roles and Statuses

| Role | Default Status | Access | Approval Required |
|------|---|---|---|
| **Reporter** | `active` | ✅ Immediate | ❌ No |
| **Supervisor** | `pending_approval` | ❌ Blocked | ✅ Yes |
| **Admin** | `active` | ✅ Immediate | ❌ No (requires code) |

### Account Statuses

- **`active`** - Account approved and can login
- **`pending_approval`** - Waiting for admin approval (cannot login)
- **`rejected`** - Admin rejected the request (cannot login)
- **`inactive`** - Admin deactivated the account (cannot login)

---

## Setup Instructions

### 1. Create Your First Admin Account

Admin signup is disabled unless the app is started with a build-time
`ADMIN_SIGNUP_CODE` value.

**Option A: Run from terminal**

```bash
flutter run --dart-define=ADMIN_SIGNUP_CODE=CHANGE_ME_ADMIN_CODE
```

**Option B: Run from VS Code**

Use the included launch configuration in `.vscode/launch.json`, then replace the
sample code with your own local admin code before running.

**Step 1:** Start the app with `ADMIN_SIGNUP_CODE` configured

**Step 2:** Click "Sign up" and fill in the form:
- First Name: Your name
- Last Name: Your name
- Email: Your email
- Password: Your password
- Role: Select **"Admin"**
- Admin Code: Enter the same code you passed in `ADMIN_SIGNUP_CODE`

**Step 3:** Click "Sign Up"

✅ Your admin account is now active and you can login immediately!

> ⚠️ **IMPORTANT:** Do not commit a real production admin code to git. Keep it in
> your local run configuration or pass it with `flutter run --dart-define=...`.

---

## Using the Admin Dashboard

### Access the Admin Dashboard
1. Login with your admin credentials
2. You'll see the **Admin Dashboard** with 4 tabs

### Tab 1: **Pending Approvals** 🕐

View all users waiting for approval (Supervisors only):

- Shows pending user details
- **Approve** button: Activates the account immediately
- **Reject** button: Blocks the user (they cannot login)

#### How to Approve a Supervisor:
1. Click the **Approve** button
2. Status changes to `active`
3. Supervisor can now login

#### How to Reject a Supervisor:
1. Click the **Reject** button
2. They'll be notified next time they try to login
3. They'll see: "Your account has been rejected. Contact administrator for details."

---

### Tab 2: **Reporters** 👥

View all active Reporters:
- See reporter names and emails
- **Deactivate** option: Temporarily blocks reporter access

---

### Tab 3: **Supervisors** 🛡️

View all active Supervisors:
- See supervisor names and emails
- **Deactivate** option: Temporarily blocks supervisor access

---

### Tab 4: **Statistics** 📊

View system statistics:
- **Total Users** - All registered users
- **Active Reporters** - Currently accessible reporters
- **Active Supervisors** - Currently accessible supervisors
- **Pending Approvals** - Users waiting for verification
- **Rejected Users** - Rejected applications

---

## User Registration Flow

### Reporter Registration
```
Reporter Signs Up
    ↓
Account Status = "active"
    ↓
Can Login Immediately ✅
```

### Supervisor Registration
```
Supervisor Signs Up
    ↓
Account Status = "pending_approval"
    ↓
Cannot Login (shown pending message) ❌
    ↓
Admin Reviews Request
    ↓
Admin Approves
    ↓
Account Status = "active"
    ↓
Supervisor Can Now Login ✅
```

### Admin Registration
```
User Signs Up (with correct Admin Code)
    ↓
Account Status = "active"
    ↓
Can Login Immediately ✅
```

---

## User Experience

### When Account is Pending Approval
When a supervisor tries to login before admin approval:

```
"Account Pending Approval"

Your [SUPERVISOR] account is awaiting admin verification and approval.
Please wait for your account to be activated.

[Logout Button]
```

### When Account is Rejected
When trying to login with a rejected account:

```
"Account Rejected"

Your account registration has been rejected by the administrator.
Please contact support for more information.

[Logout Button]
```

---

## Database Structure

User profile stored at `/users/{uid}/`:
```json
{
  "firstName": "John",
  "lastName": "Doe",
  "email": "john@company.com",
  "role": "supervisor",
  "status": "pending_approval",
  "createdAt": "2024-01-15T10:30:00.000Z"
}
```

**Key Fields:**
- `role`: "reporter" | "supervisor" | "admin"
- `status`: "active" | "pending_approval" | "rejected" | "inactive"

---

## Workflow Example

### Scenario: New Supervisor Registration

**Day 1 - Supervisor Signs Up**
1. User creates account with role "Supervisor"
2. System saves status as `pending_approval`
3. Supervisor tries to login → sees "Account Pending Approval" screen

**Day 2 - Admin Reviews**
1. Admin logs in to Admin Dashboard
2. Goes to "Pending Approvals" tab
3. Sees the supervisor's request
4. Reviews the details
5. Clicks **Approve** ✅

**Result**
- Supervisor's status changes to `active`
- Next time supervisor logs in → Access granted! ✅

---

## Best Practices

### ✅ Do:
- Review new supervisor requests within 24 hours
- Keep the admin code secure and change it regularly
- Deactivate accounts for employees who leave
- Monitor the Statistics tab to track user growth
- Document approval reasons (optional: add notes field in future)

### ❌ Don't:
- Share the admin code publicly
- Leave admin code with default value
- Approve suspicious requests without verification
- Use weak admin passwords

---

## Troubleshooting

### Problem: "Invalid admin code" error
**Solution:** Confirm the signup form code exactly matches the value passed with
`--dart-define=ADMIN_SIGNUP_CODE=...`

### Problem: "Admin sign-up is disabled in this build" error
**Solution:** Restart the app with:

```bash
flutter run --dart-define=ADMIN_SIGNUP_CODE=YOUR_SECRET_CODE
```

### Problem: Supervisor can't login after approval
**Solution:** 
1. Check Admin Dashboard → Supervisors tab
2. Confirm their status shows as ✅ Active
3. Have them logout completely and login again

### Problem: Need to unapprove someone
**Solution:**
1. Go to Admin Dashboard → Supervisors/Reporters tab
2. Click the menu (...) next to their name
3. Select "Deactivate"
4. Their status becomes "inactive"
5. They won't be able to login

---

## Future Enhancements

Consider implementing:
- **Approval notes** - Add reason when approving/rejecting
- **Email notifications** - Notify users when approved/rejected
- **Bulk approvals** - Approve multiple users at once
- **Two-factor authentication** - Extra security for admin
- **Audit log** - Track all approvals and changes
- **Department assignment** - Assign users to departments
- **Expiring codes** - Admin codes with expiration dates

---

## Need Help?

Refer to these files for implementation details:
- [lib/login.dart](lib/login.dart) - Login/Signup logic and admin code
- [lib/wrapper.dart](lib/wrapper_backup.dart) - Role routing and status checking
- [lib/admin_dashboard.dart](lib/admin_dashboard.dart) - Admin interface
