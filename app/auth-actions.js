'use server';

import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

export async function signup(_prevState, formData) {
  const fullName = String(formData.get('full_name') || '').trim();
  const email = String(formData.get('email') || '').trim();
  const password = String(formData.get('password') || '');

  if (!fullName) return { error: 'Please enter your full name.' };
  if (fullName.length > 100) return { error: 'Name must be 100 characters or fewer.' };
  if (password.length < 6) return { error: 'Password must be at least 6 characters.' };

  const supabase = await createClient();
  const { data, error } = await supabase.auth.signUp({
    email,
    password,
    // Picked up by the handle_new_user trigger to create the profile row.
    options: { data: { full_name: fullName } },
  });

  if (error) return { error: error.message };
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

  if (error) return { error: error.message };

  redirect('/dashboard');
}

export async function logout() {
  const supabase = await createClient();
  await supabase.auth.signOut();
  redirect('/login');
}
