import AuthForm from '../AuthForm';
import { safeNext } from '@/lib/safe-next';

export const metadata = { title: 'Log in · Engager' };

export default async function LoginPage({ searchParams }) {
  const { next } = await searchParams;
  return <AuthForm mode="login" next={safeNext(next)} />;
}
