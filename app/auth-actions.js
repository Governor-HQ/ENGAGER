'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

const GENERIC_ERROR = 'Something went wrong, try again.';

// Map Supabase Auth error codes to friendly text so raw errors never reach the client.
function signupErrorMessage(error) {
  switch (error.code) {
    case 'user_already_exists':
    case 'email_exists':
      return 'An account with this email already exists. Log in instead.';
    case 'weak_password':
      return 'Password must be at least 8 characters long.';
    case 'email_address_invalid':
    case 'validation_failed':
      return 'Please enter a valid email address.';
    case 'over_request_rate_limit':
    case 'over_email_send_rate_limit':
      return 'Too many attempts. Please wait a minute and try again.';
    default:
      console.error('signup failed:', error);
      return GENERIC_ERROR;
  }
}

function loginErrorMessage(error) {
  switch (error.code) {
    case 'invalid_credentials':
      return 'Incorrect email or password.';
    case 'email_not_confirmed':
      return 'Your email isn\'t confirmed yet. Contact Governor via "Need help?".';
    default:
      console.error('login failed:', error);
      return GENERIC_ERROR;
  }
}

export async function signup(_prevState, formData) {
  const fullName = String(formData.get('full_name') || '').trim();
  const email = String(formData.get('email') || '').trim();
  const password = String(formData.get('password') || '');

  if (!fullName) return { error: 'Please enter your full name.' };
  if (fullName.length > 80) return { error: 'Name must be 80 characters or fewer.' };
  if (password.length < 8) return { error: 'Password must be at least 8 characters long.' };

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    // Picked up by the handle_new_user trigger to create the profile row.
    options: { data: { full_name: fullName } },
  });

  if (error) return { error: signupErrorMessage(error) };
  if (!data.session) {
    return {
      error:
        'Account created, but email confirmation is still on in Supabase. Turn off "Confirm email" (Authentication → Sign In / Providers → Email), then log in.',
    };
  }

  redirect('/dashboard');
}

export async function login(_prevState, formData) {
  const email = String(formData.get('email') || '').trim();
  const password = String(formData.get('password') || '');

  const supabase = await createClient();
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) return { error: loginErrorMessage(error) };

  redirect('/dashboard');
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/login');
}
