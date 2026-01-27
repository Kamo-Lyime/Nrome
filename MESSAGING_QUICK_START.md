# Quick Start - Messaging Feature

## What Was Added

A complete messaging system for confirmed appointments where patients and practitioners can chat with each other.

## Setup (2 Steps)

### Step 1: Run SQL Script
Go to Supabase SQL Editor and run: `messages_table.sql`

This creates the `appointment_messages` table with proper security policies.

### Step 2: Test It

1. **Book an appointment** (as patient)
2. **Confirm the appointment** (as practitioner - click ✓ Confirm button)
3. **Click "Messages" button** that appears on confirmed appointment
4. **Start chatting!**

## Key Points

✅ **Messages button only appears on CONFIRMED appointments**
✅ **Real-time updates** - messages appear instantly
✅ **Secure** - only appointment participants can see messages
✅ **Works for both** patients and practitioners

## Files Changed

- ✅ `dashboard.html` - Added chat modal
- ✅ `js/dashboard.js` - Added messaging functions
- ✅ `css/styles.css` - Added chat styling
- ✅ `messages_table.sql` - Database table (NEW)
- ✅ `MESSAGING_FEATURE_GUIDE.md` - Full documentation (NEW)

## How to Use

**As Practitioner:**
1. View pending appointments
2. Click "✓ Confirm" on appointment
3. Click "Messages" button to chat with patient

**As Patient:**
1. Book appointment
2. Wait for confirmation
3. Click "Messages" button to chat with practitioner

That's it! The feature is ready to use after running the SQL script.
