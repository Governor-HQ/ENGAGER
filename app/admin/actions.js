'use server';

import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { cleanName, isUuid, mapDbError, MESSAGES } from './validate';

// Every action here takes (previousState, formData) so it can be used with
// useActionState. Authorization is the database: each rpc checks is_admin()
// against the logged-in session. Nothing from the form decides who may act.

async function run(label, callRpc) {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return { error: MESSAGES.sessionExpired };

    const { error } = await callRpc(supabase);
    if (error) {
      const mapped = mapDbError(error);
      if (mapped.unexpected) console.error(`${label} failed:`, error);
      return { error: mapped.message };
    }
  } catch (err) {
    console.error(`${label} threw:`, err);
    return { error: MESSAGES.generic };
  }

  revalidatePath('/admin');
  return { error: null, ok: true };
}

function field(formData, key) {
  return String(formData.get(key) || '');
}

export async function createClassroom(_prev, formData) {
  const name = cleanName(field(formData, 'name'));
  if (name.error) return { error: name.error };
  return run('createClassroom', (s) => s.rpc('create_classroom', { name: name.value }));
}

export async function createGroup(_prev, formData) {
  const classroomId = field(formData, 'classroom_id');
  const name = cleanName(field(formData, 'name'));
  if (!isUuid(classroomId)) return { error: 'Pick a classroom first.' };
  if (name.error) return { error: name.error };
  return run('createGroup', (s) =>
    s.rpc('create_group', { p_classroom_id: classroomId, p_name: name.value })
  );
}

export async function rotateCode(_prev, formData) {
  const groupId = field(formData, 'group_id');
  if (!isUuid(groupId)) return { error: MESSAGES.badInput };
  return run('rotateCode', (s) => s.rpc('rotate_invite_code', { p_group_id: groupId }));
}

export async function moveMember(_prev, formData) {
  const userId = field(formData, 'user_id');
  const fromGroupId = field(formData, 'from_group_id');
  const toGroupId = field(formData, 'to_group_id');
  if (!isUuid(userId) || !isUuid(fromGroupId)) return { error: MESSAGES.badInput };
  if (!isUuid(toGroupId)) return { error: 'Pick a group to move them to.' };
  if (toGroupId === fromGroupId) return { error: MESSAGES.sameGroup };
  return run('moveMember', (s) =>
    s.rpc('admin_move_member', {
      p_user_id: userId,
      p_from_group: fromGroupId,
      p_to_group: toGroupId,
    })
  );
}

export async function removeMember(_prev, formData) {
  const userId = field(formData, 'user_id');
  const groupId = field(formData, 'group_id');
  if (!isUuid(userId) || !isUuid(groupId)) return { error: MESSAGES.badInput };
  return run('removeMember', (s) =>
    s.rpc('admin_remove_member', { p_user_id: userId, p_group_id: groupId })
  );
}

export async function unlockAccount(_prev, formData) {
  const userId = field(formData, 'user_id');
  if (!isUuid(userId)) return { error: MESSAGES.badInput };
  return run('unlockAccount', (s) => s.rpc('admin_clear_join_lock', { p_user_id: userId }));
}
