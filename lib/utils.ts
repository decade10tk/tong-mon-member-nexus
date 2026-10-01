export function roleLabel(role: string) {
  return (
    {
      tong_chu: 'Tông chủ',
      thai_thuong_truong_lao: 'Thái thượng trưởng lão',
      truong_lao: 'Trưởng lão',
      duong_chu: 'Đường chủ',
      chap_su: 'Chấp sự',
      de_tu: 'Đệ tử',
    } as Record<string, string>
  )[role] ?? 'Đệ tử';
}