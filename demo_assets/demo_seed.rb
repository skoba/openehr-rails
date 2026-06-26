# demo_seed.rb — デモ表示用のサンプルレコードを投入する。
#
# `bin/rails runner ../demo_assets/demo_seed.rb` で実行される（build_demo.sh が呼ぶ）。
# 何度実行しても同じ結果になるよう、対象モデルの既存行を一旦消してから作り直す。
# 列名は openehr:scaffold が生成した各モデルの FIELD_MAP に対応する。

# --- BMI（OBSERVATION / DV_QUANTITY を中心とした数値テンプレート）-------------
if defined?(BmiCalculation)
  BmiCalculation.delete_all
  [
    { height: 170.0, body_weight: 65.0, body_mass_index: 22.5, body_mass_index_at0013: "標準" },
    { height: 158.0, body_weight: 48.0, body_mass_index: 19.2, body_mass_index_at0013: "標準" },
    { height: 180.0, body_weight: 95.0, body_mass_index: 29.3, body_mass_index_at0013: "肥満(1度)" },
  ].each { |attrs| BmiCalculation.create!(attrs) }
  puts "[demo_seed] BmiCalculation: #{BmiCalculation.count} records"
end

# --- 問題リスト（EVALUATION / DV_CODED_TEXT + DV_DATE_TIME）-------------------
# diagnostic_certainty は code_list ["at0074"=Suspected, "at0076"=Confirmed] のコード値。
if defined?(Problemlist)
  Problemlist.delete_all
  [
    {
      problem_diagnosis_problem_diagnosis_name: "Hypertension",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2024, 4, 1, 9, 0),
      problem_diagnosis_date_time_clinically_recognised: Time.zone.local(2024, 4, 3, 10, 30),
      problem_diagnosis_diagnostic_certainty: "at0076", # Confirmed
    },
    {
      problem_diagnosis_problem_diagnosis_name: "Type 2 diabetes mellitus",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2023, 11, 15, 8, 0),
      problem_diagnosis_diagnostic_certainty: "at0076", # Confirmed
    },
    {
      problem_diagnosis_problem_diagnosis_name: "Suspected asthma",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2025, 1, 20, 14, 0),
      problem_diagnosis_diagnostic_certainty: "at0074", # Suspected
    },
  ].each { |attrs| Problemlist.create!(attrs) }
  puts "[demo_seed] Problemlist: #{Problemlist.count} records"
end
