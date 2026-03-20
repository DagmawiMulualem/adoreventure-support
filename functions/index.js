const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const stripe = require('stripe')(functions.config().stripe?.secret_key);
const OpenAI = require('openai');
const { GoogleGenerativeAI } = require('@google/generative-ai');

// Initialize Firebase Admin
admin.initializeApp();

// Your Python backend URL (deployed on Render - Starter plan for zero cold starts)
const PYTHON_BACKEND_URL = functions.config().python_backend?.url || 'https://adoreventure-backend-clean.onrender.com';

// Configuration
const MAX_RETRIES = 2;
const TIMEOUT = 30000; // 30 seconds
const RETRY_DELAYS = [1000, 2000]; // Faster backoff delays

// OpenAI client (lazy-loaded, kept as fallback - primary route is through Render backend)
let _openai = null;
function getOpenAIClient() {
  if (!_openai) {
    _openai = new OpenAI({
      apiKey: functions.config().openai?.key || process.env.OPENAI_API_KEY,
    });
  }
  return _openai;
}

function isSpecialEventsCategory(category) {
  const c = String(category || '').toLowerCase();
  return c.includes('special');
}

function isLocalCategory(category) {
  const c = String(category || '').toLowerCase();
  return c.includes('local');
}

function enrichTimeHintForSpecialEvents(timeHint, category) {
  const baseHint = String(timeHint || '').trim();
  let categoryConstraint = '';

  if (isSpecialEventsCategory(category)) {
    categoryConstraint =
      'Only include upcoming events from today through the next 14 days; do not include past events. Include the exact date (day and month) in the title or blurb, and prefer Eventbrite or official venue booking links when available.';
  } else if (isLocalCategory(category)) {
    categoryConstraint =
      'Prioritize truly local-feeling spots: neighborhood coffee shops, VR/game places, gardens, parks, community activities, and local hangouts. Avoid tourist attractions and generic travel landmarks.';
  }

  if (!categoryConstraint) return baseHint;
  return baseHint ? `${baseHint}. ${categoryConstraint}` : categoryConstraint;
}

exports.getIdeas = functions.https.onCall(async (data, context) => {
  // Helper: generate ideas directly via OpenAI if Render backend is slow/unavailable
  async function generateIdeasDirectlyViaOpenAI() {
    const { location, category, budgetHint, timeHint, indoorOutdoor, model, previous_titles } = data;
    const trimmedLocation = String(location).trim();
    const trimmedCategory = String(category).trim() || 'Date Ideas';
    const requestedModel =
      typeof model === 'string' && model.trim() ? model.trim() : 'gpt-4o-mini';

    const prevTitles = Array.isArray(previous_titles)
      ? previous_titles
          .slice(0, 15)
          .map((t) => String(t).trim())
          .filter(Boolean)
      : [];

    const systemPrompt = [
      `You are AdoreVenture, an AI that suggests real-world ${trimmedCategory} activities.`,
      'Return JSON with exactly 3 ideas under the key "ideas".',
      'Each idea must have: title, blurb (1 sentence), rating (4.3–5.0), place, duration, priceRange, tags[], address (neighborhood + city or null), phone (or null), website (https URL), bookingURL (https URL).',
      '',
      'CONTACT & MAP SAFETY (especially lesser-known cities / emerging regions):',
      '- NEVER invent street numbers, phone numbers, or venue domains.',
      '- If you are NOT 100% sure of the official website, set "website" to a Google Search URL: https://www.google.com/search?q= plus URL-encoded query: "{place} {location} official website".',
      '- If booking/reservations URL is uncertain, set "bookingURL" to a Google Search URL with query "{place} {location} reservations tickets".',
      '- Only include phone if you are confident it is real; otherwise null.',
      '- Prefer address as area/neighborhood + city without fake building numbers.'
    ].join('\n');

    let avoid = '';
    if (prevTitles.length) {
      avoid = ` Do NOT suggest: ${prevTitles.join(
        ', '
      )}. Suggest 3 different places (different titles).`;
    }

    const effectiveTimeHint = enrichTimeHintForSpecialEvents(timeHint, trimmedCategory);
    const userPrompt =
      `Give 3 ${trimmedCategory} activities in ${trimmedLocation}.` +
      avoid +
      (budgetHint ? ` Budget: ${budgetHint}.` : '') +
      (effectiveTimeHint ? ` Time: ${effectiveTimeHint}.` : '') +
      (indoorOutdoor ? ` Setting: ${indoorOutdoor}.` : '') +
      ' Use basic admission prices only.';

    const openai = getOpenAIClient();
    const response = await openai.chat.completions.create({
      model: requestedModel,
      messages: [
        { role: 'system', content: systemPrompt },
        { role: 'user', content: userPrompt }
      ],
      temperature: 0.7,
      max_tokens: 350,
      response_format: { type: 'json_object' }
    });

    const content = response.choices[0]?.message?.content || '{}';
    let ideasData;
    try {
      ideasData = JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse OpenAI JSON for getIdeas fallback:', e, content);
      throw new functions.https.HttpsError(
        'internal',
        'AI returned invalid data. Please try again.'
      );
    }

    if (!ideasData.ideas || !Array.isArray(ideasData.ideas) || ideasData.ideas.length === 0) {
      throw new functions.https.HttpsError(
        'internal',
        'AI did not return any ideas. Please try again.'
      );
    }

    return ideasData;
  }

  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { location, category, budgetHint, timeHint, indoorOutdoor, model, userQuery, previous_titles } =
      data;

    // Validate required fields
    if (!location || !category) {
      throw new functions.https.HttpsError('invalid-argument', 'Location and category are required');
    }

    const trimmedLocation = String(location).trim();
    const trimmedCategory = String(category).trim();
    const requestedModel =
      typeof model === 'string' && model.trim() ? model.trim() : 'gpt-4o-mini';

    console.log(
      `Routing to Render backend for location: ${trimmedLocation}, category: ${trimmedCategory}, model: ${requestedModel}`
    );

    const prevTitles = Array.isArray(previous_titles) ? previous_titles.slice(0, 15) : [];
    const effectiveTimeHint = enrichTimeHintForSpecialEvents(timeHint, trimmedCategory);
    // Primary path: Render backend (fast when healthy)
    try {
      const response = await axios.post(
        `${PYTHON_BACKEND_URL}/api/ideas`,
        {
          location: trimmedLocation,
          category: trimmedCategory,
          budgetHint: budgetHint || '',
          timeHint: effectiveTimeHint,
          indoorOutdoor: indoorOutdoor || '',
          model: requestedModel,
          previous_titles: prevTitles
        },
        {
          timeout: 20000, // 20s to leave budget for fallback
          headers: { 'Content-Type': 'application/json' }
        }
      );

      const parsed = response.data;

      if (!parsed.ideas || !Array.isArray(parsed.ideas) || parsed.ideas.length === 0) {
        throw new Error('Render backend returned empty ideas array');
      }

      console.log(`Successfully received ${parsed.ideas.length} ideas from Render backend`);

      // Log successful request
      await logRequest(context.auth.uid, trimmedLocation, trimmedCategory, true);

      return parsed;
    } catch (renderError) {
      console.error('Render backend failed for getIdeas, falling back to direct OpenAI:', renderError);
      // If Render is slow or times out, fall back to OpenAI directly
      const ideasData = await generateIdeasDirectlyViaOpenAI();
      await logRequest(
        context.auth.uid,
        trimmedLocation,
        trimmedCategory,
        true,
        'fallback-openai-success'
      );
      return ideasData;
    }
  } catch (error) {
    console.error('Error in getIdeas function:', error);

    // Log failed request (best-effort)
    try {
      const { location, category } = data || {};
      await logRequest(
        context.auth?.uid || 'unknown',
        location || 'unknown',
        category || 'unknown',
        false,
        error.message || String(error)
      );
    } catch (logError) {
      console.warn('Failed to log request:', logError);
    }

    if (error.code === 'ECONNABORTED' || error.name === 'AbortError') {
      throw new functions.https.HttpsError(
        'deadline-exceeded',
        'Request timed out. Please try again.'
      );
    }

    // Re-throw HttpsErrors as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }

    // Convert other errors to HttpsError
    throw new functions.https.HttpsError(
      'internal',
      error.message || 'An unexpected error occurred'
    );
  }
});

// Single idea for streaming (client calls 3 times; log request only after all 3)
exports.getSingleIdea = functions.https.onCall(async (data, context) => {
  try {
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }
    const { location, category, index, total, previous_titles, budgetHint, timeHint, indoorOutdoor, model } = data;
    if (!location || !category) {
      throw new functions.https.HttpsError('invalid-argument', 'Location and category are required');
    }
    const trimmedLocation = String(location).trim();
    const trimmedCategory = String(category).trim();
    const requestedModel = typeof model === 'string' && model.trim() ? model.trim() : 'gpt-4o-mini';
    const idx = typeof index === 'number' ? index : 1;
    const tot = typeof total === 'number' ? total : 3;
    const prevTitles = Array.isArray(previous_titles) ? previous_titles : [];
    const effectiveTimeHint = enrichTimeHintForSpecialEvents(timeHint, trimmedCategory);

    const response = await axios.post(
      `${PYTHON_BACKEND_URL}/api/idea/single`,
      {
        location: trimmedLocation,
        category: trimmedCategory,
        index: idx,
        total: tot,
        previous_titles: prevTitles,
        budgetHint: budgetHint || '',
        timeHint: effectiveTimeHint,
        indoorOutdoor: indoorOutdoor || '',
        model: requestedModel
      },
      { timeout: 25000, headers: { 'Content-Type': 'application/json' } }
    );

    const parsed = response.data;
    if (!parsed.ideas || !Array.isArray(parsed.ideas) || parsed.ideas.length === 0) {
      throw new Error('Backend returned no idea');
    }
    return parsed;
  } catch (error) {
    console.error('Error in getSingleIdea:', error);
    if (error.code === 'ECONNABORTED' || error.name === 'AbortError') {
      throw new functions.https.HttpsError('deadline-exceeded', 'Request timed out.');
    }
    if (error instanceof functions.https.HttpsError) throw error;
    throw new functions.https.HttpsError('internal', error.message || 'An unexpected error occurred');
  }
});

// Helper function to log requests
async function logRequest(userId, location, category, success, error = null) {
  try {
    await admin.firestore().collection('idea_requests').add({
      userId,
      location,
      category,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      success,
      error: error || null
    });
  } catch (firestoreError) {
    console.warn('Failed to log to Firestore (non-critical):', firestoreError.message);
  }
}

// Provider-specific generators
async function generateIdeasWithOpenAI(prompt, modelName) {
  // Hard 10s timeout for the OpenAI call
  const controller = new AbortController();
  const timeoutId = setTimeout(() => {
    controller.abort();
  }, 10000);

  try {
    const response = await getOpenAIClient().chat.completions.create({
      model: modelName || 'gpt-4o-mini', // Fast, cost‑effective model
      messages: [
        {
          role: 'system',
          content:
            'You generate concise, real-world activity ideas and respond ONLY with strict JSON as specified.',
        },
        { role: 'user', content: prompt },
      ],
      temperature: 0.7,
      max_tokens: 300,
      response_format: { type: 'json_object' },
      signal: controller.signal,
    });

    const content = response.choices?.[0]?.message?.content;
    if (!content) {
      throw new Error('OpenAI returned empty content');
    }

    try {
      return JSON.parse(content);
    } catch (e) {
      console.error('Failed to parse OpenAI JSON:', content);
      throw new Error('AI returned invalid JSON');
    }
  } finally {
    clearTimeout(timeoutId);
  }
}

async function generateIdeasWithGemini(prompt, modelName) {
  const apiKey = functions.config().gemini?.key;
  if (!apiKey) {
    throw new Error('Gemini API key is not configured in Firebase Functions config.');
  }

  const genAI = new GoogleGenerativeAI(apiKey);
  const model = genAI.getGenerativeModel({
    model: modelName || 'gemini-1.5-flash',
  });

  const timeoutMs = 10000;
  const timeoutPromise = new Promise((_, reject) =>
    setTimeout(() => reject(new Error('Gemini request timed out')), timeoutMs)
  );

  const result = await Promise.race([
    model.generateContent({
      contents: [
        {
          role: 'user',
          parts: [
            {
              text:
                'You generate concise, real-world activity ideas and respond ONLY with strict JSON as specified.\n' +
                prompt,
            },
          ],
        },
      ],
    }),
    timeoutPromise,
  ]);

  const text = result.response?.text?.();
  if (!text) {
    throw new Error('Gemini returned empty content');
  }

  try {
    return JSON.parse(text);
  } catch (e) {
    console.error('Failed to parse Gemini JSON:', text);
    throw new Error('AI returned invalid JSON');
  }
}

exports.healthCheck = functions.https.onRequest(async (req, res) => {
  try {
    const response = await axios.get(`${PYTHON_BACKEND_URL}/health`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Backend service unavailable' });
  }
});

// MARK: - Username Management

exports.checkUsernameAvailability = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { username } = data;

    if (!username) {
      throw new functions.https.HttpsError('invalid-argument', 'Username is required');
    }

    console.log(`Checking username availability for: ${username}, user: ${context.auth.uid}`);

    // Query Firestore for username
    const snapshot = await admin.firestore().collection('users')
      .where('username', '==', username)
      .limit(1)
      .get();

    const isAvailable = snapshot.empty;
    
    console.log(`Query result - Found ${snapshot.size} documents for username '${username}'`);
    console.log(`Username '${username}' is ${isAvailable ? 'available' : 'taken'}`);

    // Log the documents found for debugging
    if (!snapshot.empty) {
      snapshot.forEach(doc => {
        console.log(`Found document with username '${username}': ${doc.id}`);
      });
    }

    return {
      success: true,
      isAvailable: isAvailable,
      message: isAvailable ? 'Username is available' : 'Username is already taken'
    };

  } catch (error) {
    console.error('Error checking username availability:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Failed to check username availability');
  }
});

exports.saveUsername = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { username } = data;

    if (!username) {
      throw new functions.https.HttpsError('invalid-argument', 'Username is required');
    }

    console.log(`Saving username '${username}' for user ${context.auth.uid}`);

    // Double-check availability before saving
    const snapshot = await admin.firestore().collection('users')
      .where('username', '==', username)
      .limit(1)
      .get();

    if (!snapshot.empty) {
      throw new functions.https.HttpsError('already-exists', 'Username is already taken');
    }

    // Save username to user document
    await admin.firestore().collection('users').doc(context.auth.uid).set({
      username: username,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Username '${username}' saved successfully for user ${context.auth.uid}`);

    return {
      success: true,
      message: 'Username saved successfully'
    };

  } catch (error) {
    console.error('Error saving username:', error);
    
    if (error.code === 'already-exists') {
      throw new functions.https.HttpsError('already-exists', 'Username is already taken');
    }
    
    throw new functions.https.HttpsError('internal', error.message || 'Failed to save username');
  }
});

// MARK: - Custom Password Reset

exports.sendCustomPasswordReset = functions.https.onCall(async (data, context) => {
  try {
    const { email } = data;
    
    if (!email) {
      throw new functions.https.HttpsError('invalid-argument', 'Email is required');
    }
    
    console.log(`Sending custom password reset email to: ${email}`);
    
    // Generate password reset link using Firebase Auth
    const actionCodeSettings = {
      url: 'https://adoreventure.com/reset-password', // Your app's password reset page
      handleCodeInApp: true,
      iOS: {
        bundleId: 'com.DagmawiMulualem.AdoreVenture'
      },
      android: {
        packageName: 'com.dagmawimulualem.adoreventure',
        installApp: true,
        minimumVersion: '1'
      },
      dynamicLinkDomain: 'adoreventure.page.link' // If you have Firebase Dynamic Links set up
    };
    
    // Send password reset email with custom settings
    await admin.auth().generatePasswordResetLink(email, actionCodeSettings);
    
    console.log(`Custom password reset email sent successfully to: ${email}`);
    
    return {
      success: true,
      message: 'Password reset email sent successfully'
    };
    
  } catch (error) {
    console.error('Error sending custom password reset email:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// MARK: - Admin Test Functions

exports.testStripeConfig = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user is admin (you can add admin email validation here)
    const adminEmails = ['dagmawi.m.mulualem@gmail.com'];
    if (!adminEmails.includes(context.auth.token.email)) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    // Test basic Stripe connectivity
    const account = await stripe.accounts.retrieve();
    
    return {
      success: true,
      environment: stripeSecretKey.startsWith('sk_test_') ? 'test' : 'live',
      accountId: account.id,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
      detailsSubmitted: account.details_submitted
    };
  } catch (error) {
    console.error('Stripe configuration test failed:', error);
    return {
      success: false,
      error: error.message,
      environment: stripeSecretKey.startsWith('sk_test_') ? 'test' : 'live'
    };
  }
});

// Admin: Grant credits to a user by email (e.g. support / promo)
exports.grantCreditsToUserByEmail = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be signed in');
  }
  const adminEmails = ['dagmawi.m.mulualem@gmail.com'];
  if (!adminEmails.includes(context.auth.token.email)) {
    throw new functions.https.HttpsError('permission-denied', 'Admin access required');
  }

  const email = (data && data.email) ? String(data.email).trim().toLowerCase() : '';
  const amount = (data && typeof data.amount === 'number') ? Math.max(0, Math.floor(data.amount)) : 0;

  if (!email || amount <= 0) {
    throw new functions.https.HttpsError('invalid-argument', 'Provide email and amount (positive number)');
  }

  try {
    const userRecord = await admin.auth().getUserByEmail(email);
    const uid = userRecord.uid;
    const db = admin.firestore();
    const userRef = db.collection('users').doc(uid);
    const snap = await userRef.get();
    const current = snap.exists ? Math.max(0, Number(snap.get('credits') || 0)) : 0;
    const newCredits = current + amount;

    await userRef.set({
      credits: newCredits,
      creditsUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Admin granted ${amount} credits to ${email} (uid: ${uid}). Was: ${current}, now: ${newCredits}`);
    return { success: true, email, uid, previousCredits: current, newCredits };
  } catch (err) {
    if (err.code === 'auth/user-not-found') {
      throw new functions.https.HttpsError('not-found', `No user found with email: ${email}`);
    }
    console.error('grantCreditsToUserByEmail error:', err);
    throw new functions.https.HttpsError('internal', err.message || 'Failed to grant credits');
  }
});

// MARK: - Stripe Payment Functions

exports.createPaymentIntent = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { planId, stripePriceId, amount, currency } = data;

    // Validate required fields
    if (!planId || !stripePriceId || !amount || !currency) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required payment information');
    }

    // Validate amount
    if (amount <= 0) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid amount');
    }

    console.log(`Creating payment intent for user ${context.auth.uid}, plan: ${planId}, amount: ${amount}, currency: ${currency}`);

    // Create payment intent with minimal configuration to avoid issues
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      automatic_payment_methods: { enabled: true },
      metadata: {
        userId: context.auth.uid,
        planId: planId,
        stripePriceId: stripePriceId
      }
      // Removed customer for now to avoid potential issues
    });

    console.log(`Payment intent created: ${paymentIntent.id}`);
    console.log(`Client secret: ${paymentIntent.client_secret}`);
    console.log(`Status: ${paymentIntent.status}`);

    return {
      paymentIntent: {
        id: paymentIntent.id,
        amount: paymentIntent.amount,
        currency: paymentIntent.currency,
        status: paymentIntent.status,
        client_secret: paymentIntent.client_secret
      }
    };

  } catch (error) {
    console.error('Error creating payment intent:', error);
    console.error('Error type:', error.type);
    console.error('Error message:', error.message);
    
    // Provide more specific error messages
    if (error.type === 'StripeInvalidRequestError') {
      throw new functions.https.HttpsError('invalid-argument', `Invalid request: ${error.message}`);
    } else if (error.type === 'StripeAuthenticationError') {
      throw new functions.https.HttpsError('unauthenticated', 'Stripe authentication failed');
    } else if (error.type === 'StripePermissionError') {
      throw new functions.https.HttpsError('permission-denied', 'Stripe permission denied');
    } else {
      throw new functions.https.HttpsError('internal', error.message || 'Failed to create payment intent');
    }
  }
});

exports.confirmPayment = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { paymentIntentId, paymentMethodId } = data;

    // Validate required fields
    if (!paymentIntentId || !paymentMethodId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing payment information');
    }

    console.log(`Confirming payment for user ${context.auth.uid}, intent: ${paymentIntentId}`);

    // Confirm the payment intent
    const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
      payment_method: paymentMethodId
    });

    if (paymentIntent.status === 'succeeded') {
      // Update user subscription status in Firestore
      await admin.firestore().collection('users').doc(context.auth.uid).set({
        isSubscribed: true,
        subscriptionDate: admin.firestore.FieldValue.serverTimestamp(),
        paymentIntentId: paymentIntentId,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      console.log(`Payment confirmed successfully for user ${context.auth.uid}`);

      return {
        success: true,
        message: 'Payment completed successfully',
        subscriptionId: paymentIntentId
      };
    } else {
      throw new Error(`Payment failed with status: ${paymentIntent.status}`);
    }

  } catch (error) {
    console.error('Error confirming payment:', error);
    return {
      success: false,
      message: error.message || 'Payment confirmation failed'
    };
  }
});

exports.createSubscription = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { planId, stripePriceId, paymentMethodId, interval } = data;

    // Validate required fields
    if (!planId || !stripePriceId || !paymentMethodId || !interval) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required subscription information');
    }

    console.log(`Creating subscription for user ${context.auth.uid}, plan: ${planId}`);

    // Create customer if doesn't exist
    let customer;
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    
    if (userDoc.exists && userDoc.data().stripeCustomerId) {
      customer = await stripe.customers.retrieve(userDoc.data().stripeCustomerId);
    } else {
      customer = await stripe.customers.create({
        email: context.auth.token.email,
        metadata: {
          firebase_uid: context.auth.uid
        }
      });

      // Save customer ID to Firestore
      await admin.firestore().collection('users').doc(context.auth.uid).set({
        stripeCustomerId: customer.id,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }

    // Attach payment method to customer
    await stripe.paymentMethods.attach(paymentMethodId, {
      customer: customer.id
    });

    // Set as default payment method
    await stripe.customers.update(customer.id, {
      invoice_settings: {
        default_payment_method: paymentMethodId
      }
    });

    // Create subscription
    const subscription = await stripe.subscriptions.create({
      customer: customer.id,
      items: [{ price: stripePriceId }],
      payment_behavior: 'default_incomplete',
      payment_settings: { save_default_payment_method: 'on_subscription' },
      expand: ['latest_invoice.payment_intent'],
      metadata: {
        userId: context.auth.uid,
        planId: planId
      }
    });

    // Update user subscription status in Firestore
    await admin.firestore().collection('users').doc(context.auth.uid).set({
      isSubscribed: true,
      subscriptionId: subscription.id,
      planId: planId,
      subscriptionDate: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Subscription created successfully: ${subscription.id}`);

    return {
      success: true,
      message: 'Subscription created successfully',
      subscriptionId: subscription.id
    };

  } catch (error) {
    console.error('Error creating subscription:', error);
    return {
      success: false,
      message: error.message || 'Subscription creation failed'
    };
  }
});

exports.cancelSubscription = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    console.log(`Cancelling subscription for user ${context.auth.uid}`);

    // Get user data to check what type of payment/subscription they have
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('not-found', 'User not found');
    }

    const userData = userDoc.data();
    const subscriptionId = userData.subscriptionId;
    const paymentIntentId = userData.paymentIntentId;
    const isSubscribed = userData.isSubscribed || false;

    console.log(`User data - subscriptionId: ${subscriptionId}, paymentIntentId: ${paymentIntentId}, isSubscribed: ${isSubscribed}`);

    if (!isSubscribed) {
      return {
        success: true,
        message: 'No active subscription found'
      };
    }

    // If user has a subscription ID, cancel it in Stripe
    if (subscriptionId) {
      try {
        console.log(`Cancelling Stripe subscription: ${subscriptionId}`);
        const subscription = await stripe.subscriptions.update(subscriptionId, {
          cancel_at_period_end: true
        });

        console.log(`Stripe subscription cancelled: ${subscriptionId}, status: ${subscription.status}`);

        // Update user subscription status in Firestore
        await admin.firestore().collection('users').doc(context.auth.uid).set({
          isSubscribed: false,
          subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        return {
          success: true,
          message: 'Subscription cancelled successfully. You will lose access at the end of your current billing period.'
        };

      } catch (stripeError) {
        console.error('Stripe error cancelling subscription:', stripeError);
        
        // If subscription doesn't exist in Stripe, just update Firestore
        if (stripeError.code === 'resource_missing') {
          console.log(`Subscription ${subscriptionId} not found in Stripe, updating Firestore only`);
          
          await admin.firestore().collection('users').doc(context.auth.uid).set({
            isSubscribed: false,
            subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });

          return {
            success: true,
            message: 'Subscription cancelled successfully'
          };
        }
        
        throw stripeError;
      }
    } 
    // If user only has a payment intent ID (one-time payment), just update Firestore
    else if (paymentIntentId) {
      console.log(`User has payment intent ${paymentIntentId}, updating Firestore only`);
      
      await admin.firestore().collection('users').doc(context.auth.uid).set({
        isSubscribed: false,
        subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      return {
        success: true,
        message: 'Premium access cancelled successfully'
      };
    }
    // If user has no payment/subscription IDs but is marked as subscribed, just update Firestore
    else {
      console.log(`User has no payment/subscription IDs, updating Firestore only`);
      
      await admin.firestore().collection('users').doc(context.auth.uid).set({
        isSubscribed: false,
        subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      return {
        success: true,
        message: 'Premium access cancelled successfully'
      };
    }

  } catch (error) {
    console.error('Error cancelling subscription:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Subscription cancellation failed');
  }
});

exports.getSubscriptionStatus = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    console.log(`Getting subscription status for user ${context.auth.uid}`);

    // Get user document from Firestore
    const userDoc = await admin.firestore().collection('users').doc(context.auth.uid).get();
    
    if (!userDoc.exists) {
      return {
        isActive: false,
        message: 'No subscription found'
      };
    }

    const userData = userDoc.data();
    const isSubscribed = userData.isSubscribed || false;
    const subscriptionId = userData.subscriptionId;

    // If user has a subscription ID, verify with Stripe
    if (subscriptionId) {
      try {
        const subscription = await stripe.subscriptions.retrieve(subscriptionId);
        const isActive = subscription.status === 'active' || subscription.status === 'trialing';
        
        // Update Firestore if status changed
        if (isActive !== isSubscribed) {
          await admin.firestore().collection('users').doc(context.auth.uid).set({
            isSubscribed: isActive,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        }

        return {
          isActive: isActive,
          subscriptionId: subscriptionId,
          status: subscription.status,
          currentPeriodEnd: subscription.current_period_end
        };
      } catch (stripeError) {
        console.error('Error retrieving subscription from Stripe:', stripeError);
        // Return Firestore status if Stripe call fails
        return {
          isActive: isSubscribed,
          subscriptionId: subscriptionId,
          message: 'Could not verify with payment provider'
        };
      }
    }

    return {
      isActive: isSubscribed,
      message: isSubscribed ? 'Subscription active' : 'No active subscription'
    };

  } catch (error) {
    console.error('Error getting subscription status:', error);
    throw new functions.https.HttpsError('internal', error.message || 'Failed to get subscription status');
  }
});

exports.getSubscriptionClientSecret = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { subscriptionId } = data;

    if (!subscriptionId) {
      throw new functions.https.HttpsError('invalid-argument', 'Subscription ID is required');
    }

    console.log(`Getting client secret for subscription: ${subscriptionId}`);

    // Retrieve the subscription with expanded latest invoice
    const subscription = await stripe.subscriptions.retrieve(subscriptionId, {
      expand: ['latest_invoice.payment_intent']
    });

    if (!subscription.latest_invoice || !subscription.latest_invoice.payment_intent) {
      throw new Error('No payment intent found for subscription');
    }

    const clientSecret = subscription.latest_invoice.payment_intent.client_secret;

    console.log(`Retrieved client secret for subscription: ${subscriptionId}`);

    return {
      success: true,
      clientSecret: clientSecret
    };

  } catch (error) {
    console.error('Error getting subscription client secret:', error);
    return {
      success: false,
      message: error.message || 'Failed to get client secret'
    };
  }
});

// Helper function to get or create a Stripe customer
async function getOrCreateCustomer(userId) {
  try {
    // First, try to find existing customer in Firestore
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    if (userDoc.exists && userDoc.data().stripeCustomerId) {
      return userDoc.data().stripeCustomerId;
    }
    
    // Create new customer in Stripe
    const customer = await stripe.customers.create({
      metadata: {
        firebaseUID: userId
      }
    });
    
    // Save customer ID to Firestore
    await admin.firestore().collection('users').doc(userId).set({
      stripeCustomerId: customer.id
    }, { merge: true });
    
    return customer.id;
  } catch (error) {
    console.error('Error getting/creating customer:', error);
    throw error;
  }
}











// Create Setup Intent for subscriptions
exports.createSetupIntent = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { planId, stripePriceId, amount, currency } = data;

    // Validate required fields
    if (!planId || !stripePriceId) {
      throw new functions.https.HttpsError('invalid-argument', 'Missing required fields');
    }

    console.log(`Creating setup intent for plan: ${planId}`);

    // Create setup intent (no amount needed for SetupIntents)
    const setupIntent = await stripe.setupIntents.create({
      payment_method_types: ['card'],
      customer: await getOrCreateCustomer(context.auth.uid),
      metadata: {
        planId: planId,
        stripePriceId: stripePriceId,
        userId: context.auth.uid
      }
    });

    console.log(`Setup intent created: ${setupIntent.id}`);

    return {
      setupIntent: {
        id: setupIntent.id,
        client_secret: setupIntent.client_secret,
        status: setupIntent.status
      }
    };

  } catch (error) {
    console.error('Error creating setup intent:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Webhook handler for Stripe events
exports.stripeWebhook = functions.https.onRequest(async (req, res) => {
  const sig = req.headers['stripe-signature'];
  const webhookSecret = functions.config().stripe?.webhook_secret;

  let event;

  try {
    event = stripe.webhooks.constructEvent(req.rawBody, sig, webhookSecret);
  } catch (err) {
    console.error('Webhook signature verification failed:', err.message);
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  console.log('Received webhook event:', event.type);

  // Handle the event
  switch (event.type) {
    case 'customer.subscription.created':
      await handleSubscriptionCreated(event.data.object);
      break;
    case 'customer.subscription.updated':
      await handleSubscriptionUpdated(event.data.object);
      break;
    case 'customer.subscription.deleted':
      await handleSubscriptionDeleted(event.data.object);
      break;
    case 'invoice.payment_succeeded':
      await handleInvoicePaymentSucceeded(event.data.object);
      break;
    case 'invoice.payment_failed':
      await handleInvoicePaymentFailed(event.data.object);
      break;
    default:
      console.log(`Unhandled event type: ${event.type}`);
  }

  res.json({ received: true });
});

// Webhook event handlers
async function handleSubscriptionCreated(subscription) {
  console.log('Subscription created:', subscription.id);
  
  const userId = subscription.metadata?.userId;
  if (!userId) {
    console.error('No userId in subscription metadata');
    return;
  }

  try {
    await admin.firestore().collection('users').doc(userId).set({
      isSubscribed: subscription.status === 'active' || subscription.status === 'trialing',
      subscriptionId: subscription.id,
      subscriptionStatus: subscription.status,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Updated user ${userId} subscription status to ${subscription.status}`);
  } catch (error) {
    console.error('Error updating user subscription:', error);
  }
}

async function handleSubscriptionUpdated(subscription) {
  console.log('Subscription updated:', subscription.id);
  
  const userId = subscription.metadata?.userId;
  if (!userId) {
    console.error('No userId in subscription metadata');
    return;
  }

  try {
    await admin.firestore().collection('users').doc(userId).set({
      isSubscribed: subscription.status === 'active' || subscription.status === 'trialing',
      subscriptionStatus: subscription.status,
      currentPeriodStart: new Date(subscription.current_period_start * 1000),
      currentPeriodEnd: new Date(subscription.current_period_end * 1000),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Updated user ${userId} subscription status to ${subscription.status}`);
  } catch (error) {
    console.error('Error updating user subscription:', error);
  }
}

async function handleSubscriptionDeleted(subscription) {
  console.log('Subscription deleted:', subscription.id);
  
  const userId = subscription.metadata?.userId;
  if (!userId) {
    console.error('No userId in subscription metadata');
    return;
  }

  try {
    await admin.firestore().collection('users').doc(userId).set({
      isSubscribed: false,
      subscriptionStatus: 'canceled',
      subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Marked user ${userId} subscription as canceled`);
  } catch (error) {
    console.error('Error updating user subscription:', error);
  }
}

async function handleInvoicePaymentSucceeded(invoice) {
  console.log('Invoice payment succeeded:', invoice.id);
  
  if (invoice.subscription) {
    const subscription = await stripe.subscriptions.retrieve(invoice.subscription);
    const userId = subscription.metadata?.userId;
    
    if (userId) {
      try {
        await admin.firestore().collection('users').doc(userId).set({
          isSubscribed: true,
          lastPaymentDate: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`Updated user ${userId} payment status`);
      } catch (error) {
        console.error('Error updating user payment status:', error);
      }
    }
  }
}

async function handleInvoicePaymentFailed(invoice) {
  console.log('Invoice payment failed:', invoice.id);
  
  if (invoice.subscription) {
    const subscription = await stripe.subscriptions.retrieve(invoice.subscription);
    const userId = subscription.metadata?.userId;
    
    if (userId) {
      try {
        await admin.firestore().collection('users').doc(userId).set({
          isSubscribed: false,
          paymentFailedAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        console.log(`Marked user ${userId} payment as failed`);
      } catch (error) {
        console.error('Error updating user payment status:', error);
      }
    }
  }
}

// MARK: - Create Payment Method Function

exports.createPaymentMethod = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { paymentMethodData } = data;
    const userId = context.auth.uid;

    // Validate required fields
    if (!paymentMethodData) {
      throw new functions.https.HttpsError('invalid-argument', 'Payment method data is required');
    }

    console.log(`Creating payment method for user: ${userId}`);

    // For Apple Pay, we need to use Stripe's PaymentSheet approach
    // Raw Apple Pay tokens cannot be directly converted to Stripe payment methods on the server
    // The correct approach is to use Stripe's PaymentSheet which handles Apple Pay natively
    
    if (paymentMethodData.type === 'card' && paymentMethodData.card?.token) {
      // This is an Apple Pay token - we need to handle it differently
      console.log('Apple Pay token detected - using secure token approach');
      
      try {
        // For Apple Pay tokens, we need to use Stripe's token API
        const token = await stripe.tokens.create({
          card: {
            token: paymentMethodData.card.token
          }
        });
        
        // Then create a payment method from the token
        const paymentMethod = await stripe.paymentMethods.create({
          type: 'card',
          card: {
            token: token.id
          },
          billing_details: paymentMethodData.billing_details || {}
        });
        
        console.log(`Apple Pay payment method created: ${paymentMethod.id}`);
        return {
          success: true,
          paymentMethodId: paymentMethod.id
        };
      } catch (error) {
        console.error('Apple Pay payment method creation failed:', error);
        throw new functions.https.HttpsError('internal', 'Apple Pay payment method creation failed. Please try again.');
      }
    } else {
      // For other payment methods
      const paymentMethod = await stripe.paymentMethods.create(paymentMethodParams);
      console.log(`Payment method created: ${paymentMethod.id}`);
      return {
        success: true,
        paymentMethodId: paymentMethod.id
      };
    }

  } catch (error) {
    console.error('Error creating payment method:', error);
    console.error('Error details:', {
      type: error.type,
      message: error.message,
      code: error.code,
      param: error.param
    });

    // Handle specific Stripe errors
    if (error.type === 'StripeInvalidRequestError') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid payment method data. Please try again.');
    } else if (error.type === 'StripeAuthenticationError') {
      throw new functions.https.HttpsError('unauthenticated', 'Payment authentication failed. Please try again.');
    } else if (error.type === 'StripePermissionError') {
      throw new functions.https.HttpsError('permission-denied', 'Payment permission denied. Please contact support.');
    } else if (error.type === 'StripeRateLimitError') {
      throw new functions.https.HttpsError('resource-exhausted', 'Too many payment requests. Please wait a moment and try again.');
    } else if (error.type === 'StripeAPIError') {
      throw new functions.https.HttpsError('internal', 'Payment service error. Please try again later.');
    } else {
      throw new functions.https.HttpsError('internal', 'Payment method creation failed. Please try again.');
    }
  }
});

// MARK: - Apple Pay Payment Confirmation Function

exports.confirmStripePayment = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { clientSecret, paymentMethodId } = data;
    const userId = context.auth.uid;

    // Validate required fields
    if (!clientSecret || !paymentMethodId) {
      throw new functions.https.HttpsError('invalid-argument', 'Client secret and payment method ID are required');
    }

    console.log(`Confirming Apple Pay payment for user: ${userId}`);
    console.log(`Payment method ID: ${paymentMethodId}`);

    // Extract payment intent ID from client secret
    const paymentIntentId = clientSecret.split('_secret_')[0];

    // Confirm the payment intent with Stripe using the payment method ID
    const paymentIntent = await stripe.paymentIntents.confirm(paymentIntentId, {
      payment_method: paymentMethodId,
      return_url: 'https://adoreventure.com/payment/return'
    });

    console.log(`Payment intent confirmed: ${paymentIntent.id}, status: ${paymentIntent.status}`);

    if (paymentIntent.status === 'succeeded') {
      // Payment succeeded - create subscription if needed
      let subscriptionId = null;
      
      // Check if this payment intent has metadata for subscription creation
      if (paymentIntent.metadata?.planId && paymentIntent.metadata?.stripePriceId) {
        try {
          // Get or create Stripe customer
          const customerId = await getOrCreateCustomer(userId);
          
          // Create subscription
          const subscription = await stripe.subscriptions.create({
            customer: customerId,
            items: [{ price: paymentIntent.metadata.stripePriceId }],
            metadata: {
              userId: userId,
              planId: paymentIntent.metadata.planId
            },
            payment_behavior: 'default_incomplete',
            payment_settings: { save_default_payment_method: 'on_subscription' },
            expand: ['latest_invoice.payment_intent']
          });

          subscriptionId = subscription.id;
          console.log(`Subscription created: ${subscriptionId}`);

          // Update user in Firestore
          await admin.firestore().collection('users').doc(userId).set({
            isSubscribed: true,
            subscriptionId: subscriptionId,
            subscriptionStatus: subscription.status,
            currentPeriodStart: new Date(subscription.current_period_start * 1000),
            currentPeriodEnd: new Date(subscription.current_period_end * 1000),
            planId: paymentIntent.metadata.planId,
            updatedAt: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });

        } catch (subscriptionError) {
          console.error('Error creating subscription:', subscriptionError);
          // Payment succeeded but subscription creation failed
          // Return success for payment but note subscription issue
        }
      }

      return {
        success: true,
        message: 'Apple Pay payment completed successfully',
        subscriptionId: subscriptionId,
        paymentIntentId: paymentIntent.id
      };

    } else if (paymentIntent.status === 'requires_action') {
      // Payment requires additional authentication (3D Secure, etc.)
      return {
        success: false,
        errorMessage: 'Payment requires additional authentication',
        requiresAction: true,
        paymentIntentId: paymentIntent.id
      };

    } else if (paymentIntent.status === 'requires_payment_method') {
      // Payment failed - card was declined
      return {
        success: false,
        errorMessage: 'Payment method was declined. Please try a different card.',
        paymentIntentId: paymentIntent.id
      };

    } else {
      // Other payment statuses
      return {
        success: false,
        errorMessage: `Payment failed with status: ${paymentIntent.status}`,
        paymentIntentId: paymentIntent.id
      };
    }

  } catch (error) {
    console.error('Error confirming Apple Pay payment:', error);
    console.error('Error details:', {
      type: error.type,
      message: error.message,
      code: error.code,
      declineCode: error.decline_code,
      param: error.param
    });

    // Handle specific Stripe errors
    if (error.type === 'StripeCardError') {
      const errorMessage = error.message || 'Your card was declined. Please try a different card.';
      throw new functions.https.HttpsError('failed-precondition', errorMessage);
    } else if (error.type === 'StripeInvalidRequestError') {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid payment request. Please try again.');
    } else if (error.type === 'StripeAuthenticationError') {
      throw new functions.https.HttpsError('unauthenticated', 'Payment authentication failed. Please try again.');
    } else if (error.type === 'StripePermissionError') {
      throw new functions.https.HttpsError('permission-denied', 'Payment permission denied. Please contact support.');
    } else if (error.type === 'StripeRateLimitError') {
      throw new functions.https.HttpsError('resource-exhausted', 'Too many payment requests. Please wait a moment and try again.');
    } else if (error.type === 'StripeAPIError') {
      throw new functions.https.HttpsError('internal', 'Payment service error. Please try again later.');
    } else {
      throw new functions.https.HttpsError('internal', 'Payment confirmation failed. Please try again.');
    }
  }
});

// MARK: - Subscription Plan Switching Function

exports.switchSubscriptionPlan = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { subscriptionId, newPlan } = data;
    const userId = context.auth.uid;

    // Validate required fields
    if (!subscriptionId || !newPlan) {
      throw new functions.https.HttpsError('invalid-argument', 'Subscription ID and new plan are required');
    }

    // Validate plan type
    if (!['monthly', 'yearly'].includes(newPlan)) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid plan type. Must be "monthly" or "yearly"');
    }

    console.log(`Switching subscription plan for user: ${userId}, subscription: ${subscriptionId}, new plan: ${newPlan}`);

    try {
      // Get current subscription from Stripe
      const currentSubscription = await stripe.subscriptions.retrieve(subscriptionId);
      
      // Determine the new price ID based on the plan
      let newPriceId;
      if (newPlan === 'monthly') {
        newPriceId = functions.config().stripe?.monthly_price_id;
      } else {
        newPriceId = functions.config().stripe?.yearly_price_id;
      }
      
      if (!newPriceId) {
        throw new functions.https.HttpsError('internal', 'Price configuration not found');
      }

      // Update the subscription with the new price
      const updatedSubscription = await stripe.subscriptions.update(subscriptionId, {
        items: [{
          id: currentSubscription.items.data[0].id,
          price: newPriceId,
        }],
        proration_behavior: 'create_prorations', // Prorate the change
      });

      console.log(`Subscription ${subscriptionId} successfully switched to ${newPlan} plan`);

      return {
        success: true,
        message: `Successfully switched to ${newPlan} plan`,
        subscriptionId: subscriptionId,
        newPlan: newPlan,
        prorationAmount: updatedSubscription.latest_invoice?.amount_due || 0
      };

    } catch (stripeError) {
      console.error('Error updating Stripe subscription:', stripeError);
      
      // Handle specific Stripe errors
      if (stripeError.type === 'StripeInvalidRequestError') {
        throw new functions.https.HttpsError('invalid-argument', 'Invalid subscription request');
      } else if (stripeError.type === 'StripeCardError') {
        throw new functions.https.HttpsError('failed-precondition', 'Payment method error');
      } else {
        throw new functions.https.HttpsError('internal', 'Failed to update subscription');
      }
    }

  } catch (error) {
    console.error('Error switching subscription plan:', error);
    
    // Re-throw Firebase Functions errors
    if (error.code) {
      throw error;
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to switch subscription plan');
  }
});

// MARK: - Subscription Cancellation Scheduling Function

exports.scheduleSubscriptionCancellation = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { subscriptionId, endDate } = data;
    const userId = context.auth.uid;

    // Validate required fields
    if (!subscriptionId || !endDate) {
      throw new functions.https.HttpsError('invalid-argument', 'Subscription ID and end date are required');
    }

    console.log(`Scheduling subscription cancellation for user: ${userId}, subscription: ${subscriptionId}`);

    // Get subscription details from Stripe to determine billing cycle
    let actualEndDate = new Date(endDate * 1000);
    
    try {
      const subscription = await stripe.subscriptions.retrieve(subscriptionId);
      
      // Use Stripe's current_period_end if available (this is the actual billing cycle end)
      if (subscription.current_period_end) {
        actualEndDate = new Date(subscription.current_period_end * 1000);
        console.log(`Using Stripe billing cycle end: ${actualEndDate}`);
      }
      
    } catch (stripeError) {
      console.log('Could not retrieve Stripe subscription, using provided end date');
    }

    // Update Firestore with cancellation schedule
    await admin.firestore().collection('users').doc(userId).set({
      isCancellationScheduled: true,
      subscriptionEndDate: actualEndDate,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Schedule the actual cancellation in Stripe at the end of the billing period
    try {
      // Update Stripe subscription to cancel at period end
      const subscription = await stripe.subscriptions.update(subscriptionId, {
        cancel_at_period_end: true
      });

      console.log(`Stripe subscription ${subscriptionId} scheduled for cancellation at period end`);

      return {
        success: true,
        message: 'Subscription cancellation scheduled successfully',
        subscriptionId: subscriptionId,
        endDate: endDate
      };

    } catch (stripeError) {
      console.error('Error updating Stripe subscription:', stripeError);
      
      // If Stripe update fails, still update Firestore and return success
      // The subscription will be handled manually or through webhooks
      return {
        success: true,
        message: 'Cancellation scheduled in app (Stripe update pending)',
        subscriptionId: subscriptionId,
        endDate: endDate
      };
    }

  } catch (error) {
    console.error('Error scheduling subscription cancellation:', error);
    throw new functions.https.HttpsError('internal', 'Failed to schedule subscription cancellation');
  }
});

// MARK: - PaymentSheet Intent Creation Function

exports.createPaymentSheetIntent = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { amount, currency, planId, stripePriceId } = data;
    const userId = context.auth.uid;

    console.log(`Received data:`, data);
    console.log(`Amount type: ${typeof amount}, value: ${amount}`);
    console.log(`Currency type: ${typeof currency}, value: ${currency}`);

    // Validate required fields
    if (!amount || !currency) {
      console.log(`Validation failed: amount=${amount}, currency=${currency}`);
      throw new functions.https.HttpsError('invalid-argument', 'Amount and currency are required');
    }

    // Ensure amount is a number
    const numericAmount = parseFloat(amount);
    if (isNaN(numericAmount) || numericAmount <= 0) {
      console.log(`Invalid amount: ${amount}`);
      throw new functions.https.HttpsError('invalid-argument', 'Amount must be a positive number');
    }

    console.log(`Creating PaymentSheet intent for user: ${userId}, amount: ${numericAmount} ${currency}`);

    // Get or create customer
    const customerId = await getOrCreateCustomer(userId);

    // Create payment intent for PaymentSheet
    const paymentIntent = await stripe.paymentIntents.create({
      amount: Math.round(numericAmount * 100), // Convert to cents
      currency: currency.toLowerCase(),
      customer: customerId,
      automatic_payment_methods: {
        enabled: true,
      },
      payment_method_types: ['card', 'apple_pay'],
      metadata: {
        userId: userId,
        planId: planId || 'unknown',
        stripePriceId: stripePriceId || 'unknown'
      }
    });

    console.log(`PaymentSheet intent created: ${paymentIntent.id}`);

    return {
      success: true,
      clientSecret: paymentIntent.client_secret,
      paymentIntentId: paymentIntent.id
    };

  } catch (error) {
    console.error('Error creating PaymentSheet intent:', error);
    console.error('Error details:', {
      message: error.message,
      type: error.type,
      code: error.code,
      raw: error
    });
    
    // Handle Stripe errors
    if (error.type && error.type.startsWith('Stripe')) {
      const stripeError = error;
      
      if (stripeError.type === 'StripeInvalidRequestError') {
        throw new functions.https.HttpsError('invalid-argument', `Invalid payment request: ${error.message}`);
      } else if (stripeError.type === 'StripeCardError') {
        throw new functions.https.HttpsError('failed-precondition', 'Payment method error');
      } else {
        throw new functions.https.HttpsError('internal', 'Payment processing error');
      }
    }
    
    throw new functions.https.HttpsError('internal', 'Failed to create payment intent');
  }
});

// MARK: - Admin Dashboard Functions

// Get Firebase usage statistics
exports.getUsageStats = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication and admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    // Check if user is admin (you can customize this logic)
    const userId = context.auth.uid;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    // For now, allow access if user exists (you can add stricter admin checks later)
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    
    // Optional: Check for admin flag if it exists
    const userData = userDoc.data();
    if (userData.isAdmin === false) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    // Get time range from request (default to 7 days)
    const { timeRange = 'week' } = data;
    let days = 7;
    
    switch (timeRange) {
      case 'day':
        days = 1;
        break;
      case 'month':
        days = 30;
        break;
      default:
        days = 7;
    }

    // Note: Firebase doesn't provide direct API access to usage statistics
    // This is a placeholder implementation. In production, you would need to:
    // 1. Set up Google Cloud Monitoring
    // 2. Use the Google Cloud Monitoring API
    // 3. Or implement your own usage tracking

    // For now, return mock data based on your current usage
    const mockStats = {
      reads: timeRange === 'day' ? 87000 : timeRange === 'month' ? 2600000 : 609000,
      writes: timeRange === 'day' ? 2 : timeRange === 'month' ? 50 : 12,
      deletes: timeRange === 'day' ? 0 : timeRange === 'month' ? 5 : 1,
      timestamp: Date.now() / 1000
    };

    console.log(`Returning usage stats for ${timeRange}:`, mockStats);
    return mockStats;

  } catch (error) {
    console.error("Error getting usage stats:", error);
    throw new functions.https.HttpsError('internal', 'Failed to get usage statistics');
  }
});

// Get billing information
exports.getBillingInfo = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication and admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    // For now, allow access if user exists (you can add stricter admin checks later)
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    
    // Optional: Check for admin flag if it exists
    const userData = userDoc.data();
    if (userData.isAdmin === false) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    // Note: This would require Google Cloud Billing API access
    // For now, return mock data
    const mockBilling = {
      balance: 0.39, // Based on your current usage
      currency: 'USD',
      lastPaymentDate: Date.now() / 1000 - (7 * 24 * 60 * 60), // 7 days ago
      nextBillingDate: Date.now() / 1000 + (23 * 24 * 60 * 60) // 23 days from now
    };

    console.log("Returning billing info:", mockBilling);
    return mockBilling;

  } catch (error) {
    console.error("Error getting billing info:", error);
    throw new functions.https.HttpsError('internal', 'Failed to get billing information');
  }
});

// Get user analytics
exports.getUserAnalytics = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication and admin access
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const userId = context.auth.uid;
    const userDoc = await admin.firestore().collection('users').doc(userId).get();
    
    // For now, allow access if user exists (you can add stricter admin checks later)
    if (!userDoc.exists) {
      throw new functions.https.HttpsError('permission-denied', 'User not found');
    }
    
    // Optional: Check for admin flag if it exists
    const userData = userDoc.data();
    if (userData.isAdmin === false) {
      throw new functions.https.HttpsError('permission-denied', 'Admin access required');
    }

    // Get actual user statistics from Firestore
    const usersSnapshot = await admin.firestore().collection('users').get();
    const totalUsers = usersSnapshot.size;

    // Calculate active users (users who have used the app in the last 7 days)
    const oneWeekAgo = new Date();
    oneWeekAgo.setDate(oneWeekAgo.getDate() - 7);

    let activeUsers = 0;
    let newUsersThisWeek = 0;

    usersSnapshot.forEach(doc => {
      const userData = doc.data();
      
      // Check if user is active (has lastActivity within 7 days)
      if (userData.lastActivity) {
        const lastActivity = userData.lastActivity.toDate();
        if (lastActivity > oneWeekAgo) {
          activeUsers++;
        }
      }

      // Check if user is new (created within 7 days)
      if (userData.createdAt) {
        const createdAt = userData.createdAt.toDate();
        if (createdAt > oneWeekAgo) {
          newUsersThisWeek++;
        }
      }
    });

    // Calculate average usage per user (based on your current stats)
    const averageUsagePerUser = totalUsers > 0 ? 609000.0 / totalUsers : 0;

    const analytics = {
      totalUsers,
      activeUsers,
      newUsersThisWeek,
      averageUsagePerUser
    };

    console.log("Returning user analytics:", analytics);
    return analytics;

  } catch (error) {
    console.error("Error getting user analytics:", error);
    throw new functions.https.HttpsError('internal', 'Failed to get user analytics');
  }
});

// Claim onboarding credits
// First account on device: 3000 credits
// Additional accounts on same device: 50 credits
exports.claimStartupBonus = functions.https.onCall(async (data, context) => {
  try {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const deviceHash = String(data?.deviceHash || "");
    if (!deviceHash || deviceHash.length < 32) {
      throw new functions.https.HttpsError('invalid-argument', 'Bad device hash.');
    }

    console.log(`Claiming startup bonus for user ${uid} on device ${deviceHash}`);

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const deviceRef = db.collection("device_claims").doc(deviceHash);

    const FIRST_ACCOUNT_CREDITS = 3000;
    const ADDITIONAL_ACCOUNT_CREDITS = 50;
    const FLOOR = 0;

    return await db.runTransaction(async (tx) => {
      const [userSnap, deviceSnap] = await Promise.all([
        tx.get(userRef),
        tx.get(deviceRef),
      ]);

      // Check whether this is the first account claim on this device
      let grantedCredits = FIRST_ACCOUNT_CREDITS;
      if (deviceSnap.exists) {
        grantedCredits = ADDITIONAL_ACCOUNT_CREDITS;
      }

      // Ensure user doc exists with at least FLOOR credits
      let credits = FLOOR;
      let startupBonusClaimed = false;
      if (userSnap.exists) {
        credits = Math.max(Number(userSnap.get("credits") || 0), FLOOR);
        startupBonusClaimed = Boolean(userSnap.get("startupBonusClaimed") || false);
      }

      if (startupBonusClaimed) {
        console.log(`User ${uid} already claimed onboarding credits, returning current credits`);
        return { credits };
      }

      // Award onboarding credits
      const newCredits = credits + grantedCredits;
      console.log(`Awarding ${grantedCredits} credits to user ${uid} (${credits} + ${grantedCredits} = ${newCredits})`);

      // Record device claim
      tx.set(deviceRef, {
        claimed: true,
        firstClaimedBy: deviceSnap.exists ? (deviceSnap.get("firstClaimedBy") || uid) : uid,
        lastClaimedBy: uid,
        claimsCount: (Number(deviceSnap.get("claimsCount") || 0) || 0) + 1,
        claimedAt: admin.firestore.FieldValue.serverTimestamp(),
        deviceHash: deviceHash
      }, { merge: true });

      // Update user credits and mark onboarding credits as claimed
      tx.set(userRef, {
        credits: newCredits,
        startupBonusClaimed: true,
        startupBonusClaimedAt: admin.firestore.FieldValue.serverTimestamp(),
        startupBonusPopupShown: true,
        startupBonusAmountGranted: grantedCredits,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });

      return { credits: newCredits };
    });

  } catch (error) {
    console.error("Error in claimStartupBonus:", error);
    
    // Re-throw Firebase function errors as-is
    if (error.code && error.message) {
      throw error;
    }
    
    // Wrap other errors
    throw new functions.https.HttpsError('internal', 'Failed to claim startup bonus');
  }
});

// Check if device is eligible for startup bonus (optional pre-check)
exports.isDeviceEligible = functions.https.onCall(async (data, context) => {
  try {
    const uid = context.auth?.uid;
    if (!uid) {
      throw new functions.https.HttpsError('unauthenticated', 'Sign in required.');
    }

    const deviceHash = String(data?.deviceHash || "");
    if (!deviceHash || deviceHash.length < 32) {
      throw new functions.https.HttpsError('invalid-argument', 'Bad device hash.');
    }

    console.log(`Checking eligibility for user ${uid} on device ${deviceHash}`);

    const db = admin.firestore();
    const userRef = db.collection("users").doc(uid);
    const deviceRef = db.collection("device_claims").doc(deviceHash);

    const [userSnap, deviceSnap] = await Promise.all([
      userRef.get(),
      deviceRef.get(),
    ]);

    // Check if device has already claimed
    if (deviceSnap.exists) {
      return { eligible: false, reason: 'device_already_claimed' };
    }

    // Check if user has already claimed
    if (userSnap.exists) {
      const startupBonusClaimed = Boolean(userSnap.get("startupBonusClaimed") || false);
      if (startupBonusClaimed) {
        return { eligible: false, reason: 'user_already_claimed' };
      }
    }

    return { eligible: true, reason: 'eligible' };

  } catch (error) {
    console.error("Error in isDeviceEligible:", error);
    
    // Re-throw Firebase function errors as-is
    if (error.code && error.message) {
      throw error;
    }
    
    // Wrap other errors
    throw new functions.https.HttpsError('internal', 'Failed to check device eligibility');
  }
});