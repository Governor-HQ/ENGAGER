'use server';

import { revalidatePath } from 'next/cache';
import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

const MESSAGES = {
  empty: 'Please enter the invite code.',
  tooLong: 'That code is too long. Check it and try again.',
  alreadyMember: 'You are already in this group.',
  invalid: 'That code is not right. Check it with whoever shared it and try again.',
  locked: 'Too many wrong tries. Try again tomorrow, or message the admin so they can unlock you.',
  notAllowed: 'Admin accounts cannot join groups.',
  sessionExpired: 'Your session has expired. Please log in again.',
  generic: 'Something went wrong, try again.',
};

export async function joinGroup(_prevState, formData) {
  const code = String(formData.get('code') || '').trim();
  if (!code) return { error: MESSAGES.empty };
  if (code.length > 40) return { error: MESSAGES.tooLong };

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: MESSAGES.sessionExpired };

  // The database normalises case, spaces and look-alike letters itself.
  const { data: status, error } = await supabase.rpc('join_group', { code });
  if (error) {
    console.error('join_group failed:', error);
    return { error: MESSAGES.generic };
  }

  switch (status) {
    case 'joined':
      revalidatePath('/dashboard');
      redirect('/dashboard');
    case 'already_member':
      return { info: MESSAGES.alreadyMember, dashboardLink: true };
    case 'invalid_code':
      return { error: MESSAGES.invalid };
    case 'locked':
      return { error: MESSAGES.locked, helpLink: true };
    case 'not_allowed':
      return { error: MESSAGES.notAllowed };
    default:
      console.error('join_group returned an unknown status:', status);
      return { error: MESSAGES.generic };
  }
}
