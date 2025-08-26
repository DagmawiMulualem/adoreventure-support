const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');
const stripe = require('stripe')(functions.config().stripe?.secret_key);

// Initialize Firebase Admin
admin.initializeApp();

// Your Python backend URL (you'll deploy this separately)
const PYTHON_BACKEND_URL = functions.config().python_backend?.url || 'https://adoreventure-backend.onrender.com';

// Configuration
const MAX_RETRIES = 3;
const TIMEOUT = 45000; // 45 seconds
const RETRY_DELAYS = [2000, 4000, 8000]; // Exponential backoff delays

exports.getIdeas = functions.https.onCall(async (data, context) => {
  try {
    // Verify authentication
    if (!context.auth) {
      throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
    }

    const { location, category, budgetHint, timeHint, indoorOutdoor } = data;

    // Validate required fields
    if (!location || !category) {
      throw new functions.https.HttpsError('invalid-argument', 'Location and category are required');
    }

    console.log(`Calling Python backend for location: ${location}, category: ${category}`);

    // Retry logic with exponential backoff
    let lastError;
    
    for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
      try {
        console.log(`Attempt ${attempt}/${MAX_RETRIES}`);
        
        // Call Python backend with timeout
        const response = await axios.post(`${PYTHON_BACKEND_URL}/api/ideas`, {
          location,
          category,
          budgetHint,
          timeHint,
          indoorOutdoor
        }, {
          headers: {
            'Content-Type': 'application/json'
          },
          timeout: TIMEOUT
        });

        console.log('Python backend response received:', response.status);

        // Validate response
        if (!response.data || !response.data.ideas) {
          throw new Error('Invalid response format from backend');
        }

        // Log successful request
        await logRequest(context.auth.uid, location, category, true);

        return response.data;

      } catch (error) {
        lastError = error;
        console.error(`Attempt ${attempt} failed:`, error.message);

        // Don't retry on validation errors
        if (error.code === 'invalid-argument' || error.code === 'unauthenticated') {
          throw error;
        }

        // Wait before retrying (except on last attempt)
        if (attempt < MAX_RETRIES) {
          const delay = RETRY_DELAYS[attempt - 1];
          console.log(`Retrying in ${delay}ms...`);
          await new Promise(resolve => setTimeout(resolve, delay));
        }
      }
    }

    // All retries failed
    console.error('All retries failed:', lastError.message);
    
    // Log failed request
    await logRequest(context.auth.uid, location, category, false, lastError.message);

    // Provide specific error messages based on the type of failure
    if (lastError.code === 'ECONNABORTED') {
      throw new functions.https.HttpsError('deadline-exceeded', 'Request timed out. Please try again.');
    } else if (lastError.response) {
      const status = lastError.response.status;
      if (status >= 500) {
        throw new functions.https.HttpsError('internal', 'Backend service temporarily unavailable. Please try again in a moment.');
      } else if (status === 404) {
        throw new functions.https.HttpsError('not-found', 'Location not found. Please try a different location.');
      } else {
        throw new functions.https.HttpsError('internal', `Backend error (${status}). Please try again.`);
      }
    } else {
      throw new functions.https.HttpsError('internal', 'Unable to connect to our services. Please check your internet connection and try again.');
    }

  } catch (error) {
    console.error('Error in getIdeas function:', error);
    
    // Re-throw HttpsErrors as-is
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    // Convert other errors to HttpsError
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

exports.healthCheck = functions.https.onRequest(async (req, res) => {
  try {
    const response = await axios.get(`${PYTHON_BACKEND_URL}/health`);
    res.json(response.data);
  } catch (error) {
    res.status(500).json({ error: 'Backend service unavailable' });
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

    console.log(`Creating payment intent for user ${context.auth.uid}, plan: ${planId}`);

    // Create payment intent with Stripe
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amount,
      currency: currency,
      metadata: {
        userId: context.auth.uid,
        planId: planId
      }
    });

    console.log(`Payment intent created: ${paymentIntent.id}`);

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
    throw new functions.https.HttpsError('internal', error.message || 'Failed to create payment intent');
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

    const { subscriptionId } = data;

    if (!subscriptionId) {
      throw new functions.https.HttpsError('invalid-argument', 'Subscription ID is required');
    }

    console.log(`Cancelling subscription for user ${context.auth.uid}, subscription: ${subscriptionId}`);

    // Cancel subscription in Stripe
    const subscription = await stripe.subscriptions.update(subscriptionId, {
      cancel_at_period_end: true
    });

    // Update user subscription status in Firestore
    await admin.firestore().collection('users').doc(context.auth.uid).set({
      isSubscribed: false,
      subscriptionCancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    console.log(`Subscription cancelled successfully: ${subscriptionId}`);

    return {
      success: true,
      message: 'Subscription cancelled successfully'
    };

  } catch (error) {
    console.error('Error cancelling subscription:', error);
    return {
      success: false,
      message: error.message || 'Subscription cancellation failed'
    };
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
