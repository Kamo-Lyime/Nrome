# Appointment Messaging Feature - Setup Guide

## Overview
This feature enables patients and practitioners to send messages to each other through a chatbox modal. The messaging feature is only available for **confirmed appointments**.

## Features
- ✅ Real-time messaging between patient and practitioner
- ✅ Only available for confirmed appointments
- ✅ Beautiful chat interface with message bubbles
- ✅ Auto-scroll to latest messages
- ✅ Message read tracking
- ✅ Real-time updates using Supabase subscriptions
- ✅ Secure with Row Level Security policies

## Setup Instructions

### 1. Create the Messages Table in Supabase

Run the SQL script `messages_table.sql` in your Supabase SQL editor:

```bash
# The file contains:
- appointment_messages table creation
- Indexes for performance
- Row Level Security policies
```

**Or manually run this in Supabase SQL Editor:**

1. Go to your Supabase Dashboard
2. Navigate to SQL Editor
3. Copy and paste the contents of `messages_table.sql`
4. Click "Run" to execute

### 2. Files Modified

The following files have been updated:

1. **dashboard.html**
   - Added messaging modal with chat interface
   - Includes message input and send button

2. **js/dashboard.js**
   - Added messaging functions:
     - `openMessagesModal()` - Opens chat modal for an appointment
     - `loadMessages()` - Loads all messages for an appointment
     - `sendMessage()` - Sends a new message
     - `subscribeToMessages()` - Real-time message updates
     - `markMessagesAsRead()` - Marks messages as read
   - Updated appointment rendering to include "Messages" button for confirmed appointments

3. **css/styles.css**
   - Added custom styles for chat bubbles
   - Smooth animations for new messages
   - Custom scrollbar styling

### 3. How It Works

#### For Practitioners:
1. Patient books an appointment (status: "pending")
2. Practitioner confirms the appointment (status changes to "confirmed")
3. A "Messages" button appears on the confirmed appointment
4. Both practitioner and patient can now send messages

#### For Patients:
1. After booking, wait for practitioner to confirm
2. Once confirmed, the "Messages" button appears
3. Click to start messaging with the practitioner

### 4. Database Schema

```sql
appointment_messages
├── id (UUID, Primary Key)
├── appointment_id (UUID, Foreign Key to appointments)
├── sender_id (UUID, Foreign Key to auth.users)
├── sender_name (TEXT)
├── sender_role (TEXT: 'patient' or 'practitioner')
├── message (TEXT)
├── created_at (TIMESTAMPTZ)
├── read_at (TIMESTAMPTZ, nullable)
└── is_read (BOOLEAN)
```

### 5. Security

The messaging feature uses Supabase Row Level Security (RLS):

- ✅ Users can only view messages for appointments they're involved in
- ✅ Messages can only be sent for confirmed appointments
- ✅ Only participants can mark messages as read
- ✅ All operations are authenticated

### 6. Real-time Updates

The feature uses Supabase real-time subscriptions:
- New messages appear instantly without page refresh
- Messages are automatically marked as read when viewed
- Clean subscription management (unsubscribes when modal closes)

### 7. Testing the Feature

1. **Create a test appointment:**
   - Login as a patient
   - Book an appointment with a practitioner

2. **Confirm the appointment:**
   - Login as the practitioner (or switch accounts)
   - Go to dashboard
   - Click "✓ Confirm" on the appointment

3. **Start messaging:**
   - Click the "Messages" button that appears on the confirmed appointment
   - Type a message and press Enter or click Send
   - Messages appear instantly for both parties

4. **Test as both roles:**
   - Open two browser windows (or use incognito mode)
   - Login as patient in one, practitioner in another
   - Send messages back and forth

### 8. UI Features

- **Message Bubbles:**
  - Your messages appear on the right (blue background)
  - Other person's messages appear on the left (white background)
  
- **Timestamps:**
  - Each message shows when it was sent
  
- **Appointment Info:**
  - Header shows who you're chatting with
  - Shows the appointment date

- **Auto-scroll:**
  - Chat automatically scrolls to show latest messages

### 9. Troubleshooting

**Messages not appearing?**
- Check that the appointment status is "confirmed"
- Verify the messages_table.sql was executed successfully
- Check browser console for errors

**Button not showing?**
- Only confirmed appointments show the Messages button
- Refresh the page after confirming an appointment

**Real-time not working?**
- Ensure Supabase real-time is enabled for the appointment_messages table
- Check that subscriptions are properly set up

### 10. Future Enhancements

Potential features to add:
- 📎 File attachments
- 📢 Push notifications for new messages
- ✅ Typing indicators
- 🔔 Unread message count badges
- 📱 Mobile app integration
- 🗑️ Delete messages
- ✏️ Edit sent messages
- 🔍 Search message history

## Support

If you encounter any issues, check:
1. Supabase console for database errors
2. Browser console for JavaScript errors
3. Network tab to see if API calls are succeeding

---

**Note:** This feature requires both parties to be logged in to see real-time updates. Messages are stored permanently in the database and can be viewed anytime after sending.
