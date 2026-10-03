'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';

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
  const url = String(formData.get('url') || '').trim();

  if (!isLinkedInUrl(url) || url.length > 500) {
    return { error: 'Please paste a valid LinkedIn post link (https://www.linkedin.com/…).' };
  }

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: 'Your session has expired. Please log in again.' };

  const { error } = await supabase.from('posts').insert({ user_id: user.id, url });

  if (error) {
    if (error.code === '23505') return { error: "You've already submitted a post today." };
    if (error.code === '23514') return { error: 'That link was rejected. Use a LinkedIn post URL.' };
    return { error: error.message };
  }

  revalidatePath('/dashboard');
  return { error: null };
}

export async function markEngaged(_prevState, formData) {
  const postId = String(formData.get('post_id') || '');

  const supabase = await createClient();
  const {
    data: { user },
  } = await supabase.auth.getUser();
  if (!user) return { error: 'Your session has expired. Please log in again.' };

  const { error } = await supabase
    .from('engagements')
    .insert({ post_id: postId, user_id: user.id });

  // 23505 = already engaged; treat as success so the button just flips.
  if (error && error.code !== '23505') {
    if (error.code === '23514') return { error: "You can't engage with your own post." };
    return { error: 'Could not save. Please try again.' };
  }

  revalidatePath('/dashboard');
  return { error: null };
}
