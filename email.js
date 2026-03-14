const nodemailer = require('nodemailer');

let transporter;

function getTransporter() {
  if (!transporter) {
    transporter = nodemailer.createTransport({
      host:   process.env.SMTP_HOST,
      port:   parseInt(process.env.SMTP_PORT || '587'),
      secure: process.env.SMTP_PORT === '465',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });
  }
  return transporter;
}

async function sendOTPEmail(email, username, code, purpose) {
  const subjects = {
    login_2fa:      'Your GameVault login code',
    verify_email:   'Verify your GameVault email',
    reset_password: 'Reset your GameVault password',
  };
  const labels = {
    login_2fa:      'Sign-in verification',
    verify_email:   'Email verification',
    reset_password: 'Password reset',
  };

  const html = `
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"/></head>
<body style="font-family:'DM Sans',system-ui,sans-serif;background:#0f0f13;margin:0;padding:40px 20px;">
  <div style="max-width:420px;margin:0 auto;background:#1a1a24;border-radius:16px;overflow:hidden;border:1px solid rgba(255,255,255,0.07)">
    <div style="background:linear-gradient(135deg,#7c6af7,#c47fff);padding:28px 32px;text-align:center">
      <div style="font-size:32px;margin-bottom:8px">🎮</div>
      <h1 style="color:#fff;margin:0;font-size:1.4rem;font-weight:800;letter-spacing:-0.03em">GameVault</h1>
    </div>
    <div style="padding:32px">
      <p style="color:#9090a8;margin:0 0 6px;font-size:0.85rem;text-transform:uppercase;letter-spacing:0.06em">${labels[purpose] || 'Verification'}</p>
      <p style="color:#f0f0f5;margin:0 0 24px;font-size:1rem">Hi ${username}, here's your code:</p>
      <div style="background:#0f0f13;border-radius:12px;padding:20px;text-align:center;margin-bottom:24px;letter-spacing:0.3em;font-size:2rem;font-weight:800;color:#a394ff;font-family:monospace">
        ${code}
      </div>
      <p style="color:#5a5a72;font-size:0.8rem;margin:0">This code expires in <strong style="color:#9090a8">10 minutes</strong> and can only be used once. If you didn't request this, you can safely ignore this email.</p>
    </div>
  </div>
</body>
</html>`;

  await getTransporter().sendMail({
    from:    process.env.EMAIL_FROM || 'GameVault <noreply@gamevault.app>',
    to:      email,
    subject: subjects[purpose] || 'Your GameVault code',
    html,
  });
}

module.exports = { sendOTPEmail };
