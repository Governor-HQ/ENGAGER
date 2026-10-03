'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

const MESSAGES = {
  duplicatePost:
    "You've already submitted a post for today. Come back tomorrow for your next one.",
  badUrl:
    "That doesn't look like a LinkedIn post link. Paste the full URL starting with https://www.linkedin.com or https://lnkd.in.",
  alreadyEngaged: "You've already marked this one as engaged.",
  ownPost: "You can't engage with your own post.",
  sessionExpired: 'Your session has expired. Please log in again.',
  generic: 'Something went wrong, try again.',
};

// Postgres error codes returned by Supabase.
const UNIQUE_VIOLATION = '23505';
const CHECK_VIOLATION = '23514';

function isLinkedInUrl(value) {
  try {
    const url = new URL(value);
    const host = url.hostname.toLowerCase();
    return (
      url.protocol === 'https:' &&
      (host === 'linkedin.com' || host.endsWith('.linkedin.com') || host === 'lnkd.in')
    );
  } catch {
    return false;
  }
}

export async function submitPost(_prevState, formData) {
  try {
    const url = String(formData.get('url') || '').trim();
    if (!isLinkedInUrl(url) || url.length > 500) return { error: MESSAGES.badUrl };

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return { error: MESSAGES.sessionExpired };

    const { error } = await supabase.from('posts').insert({ user_id: user.id, url });

    if (error) {
      if (error.code === UNIQUE_VIOLATION) return { error: MESSAGES.duplicatePost };
      // The only CHECK constraints on posts are the URL pattern and length.
      if (error.code === CHECK_VIOLATION) return { error: MESSAGES.badUrl };
      console.error('submitPost failed:', error);
      return { error: MESSAGES.generic };
    }
  } catch (err) {
    console.error('submitPost threw:', err);
    return { error: MESSAGES.generic };
  }

  revalidatePath('/dashboard');
  return { error: null };
}

export async function markEngaged(_prevState, formData) {
  try {
    const postId = String(formData.get('post_id') || '');

    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return { error: MESSAGES.sessionExpired };

    const { error } = await supabase
      .from('engagements')
      .insert({ post_id: postId, user_id: user.id });

    if (error) {
      if (error.code === UNIQUE_VIOLATION) {
        // Refresh so the button flips to "Engaged ✓" alongside the message.
        revalidatePath('/dashboard');
        return { error: MESSAGES.alreadyEngaged };
      }
      // Raised by the prevent_self_engagement trigger.
      if (error.code === CHECK_VIOLATION) return { error: MESSAGES.ownPost };
      console.error('markEngaged failed:', error);
      return { error: MESSAGES.generic };
    }
  } catch (err) {
    console.error('markEngaged threw:', err);
    return { error: MESSAGES.generic };
  }

  revalidatePath('/dashboard');
  return { error: null };
}
