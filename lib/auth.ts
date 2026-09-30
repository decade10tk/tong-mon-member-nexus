import { redirect } from 'next/navigation';
import { createClient } from '@/lib/supabase/server';

export async function getSessionProfile() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { supabase, user: null, profile: null };
  const { data: profile } = await supabase.from('profiles').select('*').eq('id', user.id).maybeSingle();
  return { supabase, user, profile };
}
export async function requireApproved() {
  const result = await getSessionProfile();
  if (!result.user) redirect('/login');
  if (!result.profile || result.profile.status !== 'approved') redirect('/pending');
  return result as typeof result & { user: NonNullable<typeof result.user>; profile: NonNullable<typeof result.profile> };
}
export async function requireManager() {
  const result = await requireApproved();
  if (!['tong_chu', 'thai_thuong_truong_lao'].includes(result.profile.role)) redirect('/members');
  return result;
}
