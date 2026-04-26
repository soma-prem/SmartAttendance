class CollegeData {
  static const List<String> branches = ['CSE', 'IT', 'ME', 'CE', 'ENTC', 'ECM'];

  static const List<String> divisions = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'F',
    'G',
    'H',
    'I',
    'NA',
  ];

  static List<String> divisionsForYear(int? year) {
    return divisions;
  }

  static const List<int> years = [1, 2, 3, 4];

  static const List<int> semesters = [1, 2, 3, 4, 5, 6, 7, 8];
}
