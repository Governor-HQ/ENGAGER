import JoinForm from '../JoinForm';

export const metadata = { title: 'Join a group · Engager' };

// The code comes from the URL. It is only ever used as the input's
// defaultValue, which React escapes. Decoded safely and capped at 40 chars.
function readCode(raw) {
  let value = String(raw ?? '');
  try {
    value = decodeURIComponent(value);
  } catch {
    // Malformed escape: keep the raw text.
  }
  return value.trim().slice(0, 40);
}

export default async function JoinCodePage({ params }) {
  const { code } = await params;
  return <JoinForm initialCode={readCode(code)} />;
}
