'use server';
import { redirect } from 'next/navigation';
import { revalidatePath } from 'next/cache';
import { createClient } from '@/lib/supabase/server';
import { requireManager, requireApproved } from '@/lib/auth';

function val(form: FormData, key: string) { return String(form.get(key) ?? '').trim(); }
export async function signIn(form: FormData) {
 const email=val(form,'email'), password=val(form,'password');
 const supabase=await createClient(); const {error}=await supabase.auth.signInWithPassword({email,password});
 if(error) redirect('/login?error='+encodeURIComponent('Đăng nhập thất bại. Hãy kiểm tra email và mật khẩu.'));
 redirect('/pending');
}
export async function signUp(form: FormData) {
 const display_name=val(form,'display_name'), email=val(form,'email'), password=val(form,'password');
 const minecraft_username=val(form,'minecraft_username'), discord_username=val(form,'discord_username');
 if(display_name.length<2||display_name.length>40||password.length<8) redirect('/register?error='+encodeURIComponent('Kiểm tra tên hiển thị hoặc mật khẩu (tối thiểu 8 ký tự).'));
 const supabase=await createClient();
 const {error}=await supabase.auth.signUp({email,password,options:{data:{display_name,minecraft_username,discord_username}}});
 if(error) redirect('/register?error='+encodeURIComponent('Không thể tạo tài khoản. Email có thể đã được sử dụng hoặc cấu hình email chưa hoàn tất.'));
 redirect('/register?success='+encodeURIComponent('Đã gửi đăng ký. Nếu dự án yêu cầu xác minh email, hãy mở email xác minh; sau đó chờ Tông chủ duyệt tài khoản.'));
}
export async function signOut() { const supabase=await createClient(); await supabase.auth.signOut(); redirect('/'); }
export async function updateMyProfile(form: FormData) {
 const {supabase,user}=await requireApproved();
 const display_name=val(form,'display_name'), minecraft_username=val(form,'minecraft_username'), discord_username=val(form,'discord_username'), bio=val(form,'bio'), avatar_url=val(form,'avatar_url');
 if(display_name.length<2||display_name.length>40) redirect('/pending?error='+encodeURIComponent('Tên hiển thị phải từ 2 đến 40 ký tự.'));
 const {error}=await supabase.from('profiles').update({display_name,minecraft_username,discord_username,bio,avatar_url}).eq('id',user.id);
 if(error) redirect('/pending?error='+encodeURIComponent('Không thể lưu hồ sơ. Kiểm tra URL ảnh và thử lại.'));
 revalidatePath('/pending'); revalidatePath('/members'); redirect('/pending?saved=1');
}
export async function reviewMembership(form: FormData) {
 const {supabase}=await requireManager(); const user_id=val(form,'user_id'), decision=val(form,'decision');
 if(!user_id||!['approve','reject'].includes(decision)) redirect('/admin?error='+encodeURIComponent('Yêu cầu không hợp lệ.'));
 const {error}=await supabase.rpc('review_membership',{target_user_id:user_id,approve_request:decision==='approve'});
 if(error) redirect('/admin?error='+encodeURIComponent('Không thể xử lý đơn. Hãy kiểm tra quyền và migration SQL.'));
 revalidatePath('/admin'); revalidatePath('/members'); redirect('/admin?updated=1');
}
export async function changeMemberRole(form: FormData) {
 const {supabase}=await requireManager(); const user_id=val(form,'user_id'), new_role=val(form,'new_role');
 const allowed=['thai_thuong_truong_lao','truong_lao','duong_chu','chap_su','de_tu'];
 if(!user_id||!allowed.includes(new_role)) redirect('/admin?error='+encodeURIComponent('Cấp bậc không hợp lệ.'));
 const {error}=await supabase.rpc('change_member_role',{target_user_id:user_id,new_role});
 if(error) redirect('/admin?error='+encodeURIComponent('Không thể đổi cấp bậc. Quyền hạn được xác minh trong database.'));
 revalidatePath('/admin'); revalidatePath('/members'); redirect('/admin?updated=1');
}
