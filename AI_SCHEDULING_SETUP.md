# AI Scheduling Suggestions Setup Guide

## Overview
The AI-Powered Appointment Booking now saves and displays scheduling recommendations to both patients and practitioners.

## Database Setup Required

To enable this feature, run the SQL migration in your Supabase database.

### Step 1: Access Supabase SQL Editor

1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your project: **vpmuooztcqzrrfsvjzwl**
3. Click on **SQL Editor** in the left sidebar

### Step 2: Run the Migration

1. Click **New Query**
2. Copy the entire contents of `add_ai_scheduling_column.sql`
3. Paste and click **Run**

### Step 3: Verify Column Added

1. Go to **Table Editor** → **appointments**
2. Verify new column exists: `ai_scheduling_suggestion` (TEXT)

## How It Works

### When Booking an Appointment

1. Patient fills in appointment details
2. Clicks **Get AI Scheduling Recommendations** button
3. AI analyzes symptoms and generates scheduling advice
4. AI suggestion appears in the "AI Smart Scheduling" box
5. When booking is confirmed, the AI suggestion is:
   - Saved with the appointment
   - Shown in the confirmation alert
   - Displayed in the dashboard

### What's Displayed

**Confirmation Alert Shows:**
```
✅ Appointment Request Sent Successfully!

Booking ID: APT-123456
Patient: John Doe
Practitioner: Dr. Smith
Date: January 28, 2026 at 10:00 AM

Reason for Visit: Tooth pain

🤖 AI Scheduling Recommendation:
Based on your symptoms (tooth pain), we recommend:
- Priority: ROUTINE
- Recommended Specialist: Dentist
- Timeframe: Within 48-72 hours
- Action: Schedule consultation with dentist

Status: Pending Practitioner Confirmation
```

**Dashboard Shows:**
- Both patient and practitioner see AI recommendations
- Appears in blue info box below appointment details
- Includes complete AI analysis and scheduling advice

### Benefits for Practitioners

- **Instant Context**: See AI assessment before appointment
- **Better Preparation**: Understand patient urgency level
- **Efficient Scheduling**: AI helps identify urgent cases
- **Improved Care**: Know specialist recommendations upfront

### Benefits for Patients

- **Clear Expectations**: Understand appointment priority
- **Informed Decisions**: Know recommended timeframes
- **Better Communication**: AI suggestion shared with practitioner
- **Transparency**: See reasoning behind scheduling

## Features

✅ **AI-Powered Analysis**: Evaluates symptoms for urgency  
✅ **Smart Recommendations**: Suggests specialist type and timeframe  
✅ **Persistent Storage**: Saved in database for future reference  
✅ **Dual Visibility**: Both patient and practitioner see suggestions  
✅ **Context Preservation**: Appointment includes full AI analysis  

## Example AI Suggestions

**High Priority Case:**
```
🤖 AI Scheduling Recommendation:
Priority: HIGH PRIORITY
Symptoms indicate potential serious condition requiring prompt attention.
Recommended: See emergency care or urgent care facility within 24 hours.
Specialist: Emergency Medicine
```

**Routine Case:**
```
🤖 AI Scheduling Recommendation:
Priority: ROUTINE
Symptoms suggest manageable condition.
Recommended: Schedule regular appointment within 48-72 hours.
Specialist: General Practitioner
```

## Troubleshooting

### AI Suggestion Not Showing
1. Make sure SQL column was added successfully
2. Click "Get AI Scheduling Recommendations" button before booking
3. Check that reason for visit is filled in

### Suggestion Not in Dashboard
1. Verify the appointment was created after adding the column
2. Refresh the dashboard page
3. Check browser console for errors

---

**Need Help?** All changes have been deployed to production automatically via GitHub Pages.
