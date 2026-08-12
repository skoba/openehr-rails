# demo_seed.rb — デモ表示用のサンプルレコードを投入する。
#
# `bin/rails runner ../demo_assets/demo_seed.rb` で実行される（build_demo.sh が呼ぶ）。
# 何度実行しても同じ結果になるよう、対象モデルの既存行を一旦消してから作り直す。
# 列名は openehr:scaffold が生成した各モデルの FIELD_MAP に対応する。
#
# 3名の患者(固定 ehr_id)を軸に、BMI/血圧/問題リストを日付を跨いで交錯させる
# ("患者タイムライン" /ehrs 画面で横断表示できることを確認するため)。
# patient-001 の初回 BMI レコードは 1 件だけ update! して修正履歴(amend)を作る。

PATIENTS = {
  "patient-001" => "Taro Yamada",
  "patient-002" => "Hanako Suzuki",
  "patient-003" => "Ichiro Tanaka",
}.freeze

# --- BMI（OBSERVATION / DV_QUANTITY を中心とした数値テンプレート）-------------
if defined?(BmiCalculation)
  BmiCalculation.delete_all
  [
    { ehr_id: "patient-001", composed_at: Time.zone.local(2024, 4, 1, 9, 0),
      height: 170.0, body_weight: 66.0, body_mass_index: 22.8, body_mass_index_at0013: "標準" },
    { ehr_id: "patient-001", composed_at: Time.zone.local(2025, 1, 20, 9, 15),
      height: 170.0, body_weight: 65.0, body_mass_index: 22.5, body_mass_index_at0013: "標準" },
    { ehr_id: "patient-002", composed_at: Time.zone.local(2024, 11, 15, 8, 30),
      height: 158.0, body_weight: 48.0, body_mass_index: 19.2, body_mass_index_at0013: "標準" },
    { ehr_id: "patient-003", composed_at: Time.zone.local(2025, 1, 20, 14, 30),
      height: 180.0, body_weight: 95.0, body_mass_index: 29.3, body_mass_index_at0013: "肥満(1度)" },
  ].each { |attrs| BmiCalculation.create!(attrs) }

  # 修正履歴のデモ: patient-001 の最初の BMI 記録を後日訂正 (amendment としてバージョン2が積まれる)。
  first_bmi = BmiCalculation.where(ehr_id: "patient-001").order(:composed_at).first
  first_bmi.update!(body_weight: 65.5, body_mass_index: 22.7)

  puts "[demo_seed] BmiCalculation: #{BmiCalculation.count} records"
end

# --- 問題リスト（EVALUATION / DV_CODED_TEXT + DV_DATE_TIME）-------------------
# diagnostic_certainty は code_list ["at0074"=Suspected, "at0076"=Confirmed] のコード値。
if defined?(Problemlist)
  Problemlist.delete_all
  [
    {
      ehr_id: "patient-001", composed_at: Time.zone.local(2024, 4, 3, 10, 30),
      problem_diagnosis_problem_diagnosis_name: "Hypertension",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2024, 4, 1, 9, 0),
      problem_diagnosis_date_time_clinically_recognised: Time.zone.local(2024, 4, 3, 10, 30),
      problem_diagnosis_diagnostic_certainty: "at0076", # Confirmed
    },
    {
      ehr_id: "patient-002", composed_at: Time.zone.local(2023, 11, 15, 8, 0),
      problem_diagnosis_problem_diagnosis_name: "Type 2 diabetes mellitus",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2023, 11, 15, 8, 0),
      problem_diagnosis_diagnostic_certainty: "at0076", # Confirmed
    },
    {
      ehr_id: "patient-003", composed_at: Time.zone.local(2025, 1, 20, 14, 0),
      problem_diagnosis_problem_diagnosis_name: "Suspected asthma",
      problem_diagnosis_date_time_of_onset: Time.zone.local(2025, 1, 20, 14, 0),
      problem_diagnosis_diagnostic_certainty: "at0074", # Suspected
    },
  ].each { |attrs| Problemlist.create!(attrs) }
  puts "[demo_seed] Problemlist: #{Problemlist.count} records"
end

# --- 血圧（OBSERVATION / 脈拍 + 収縮期/拡張期血圧の DV_QUANTITY 複数）---------
# 1 テンプレートに heart_rate-pulse と blood_pressure の 2 アーキタイプが同居し、
# 列名はそれぞれ heart_rate_pulse / blood_pressure_systolic / _diastolic になる。
if defined?(PatientBloodPressure)
  PatientBloodPressure.delete_all
  [
    { ehr_id: "patient-001", composed_at: Time.zone.local(2025, 1, 20, 9, 20),
      heart_rate_pulse: 72, blood_pressure_systolic: 120, blood_pressure_diastolic: 80 },
    { ehr_id: "patient-002", composed_at: Time.zone.local(2024, 11, 15, 8, 35),
      heart_rate_pulse: 88, blood_pressure_systolic: 148, blood_pressure_diastolic: 92 },
    { ehr_id: "patient-003", composed_at: Time.zone.local(2025, 1, 20, 14, 35),
      heart_rate_pulse: 60, blood_pressure_systolic: 110, blood_pressure_diastolic: 70 },
  ].each { |attrs| PatientBloodPressure.create!(attrs) }
  puts "[demo_seed] PatientBloodPressure: #{PatientBloodPressure.count} records"
end

# --- EHR の subject_id (患者名) を補完 ----------------------------------------
# 上記の各 create! が Storable 経由で Rm::Ehr を find_or_create_by!(ehr_id:) して
# いるので、ここで subject_id を後付けする (患者タイムライン一覧の表示用)。
if defined?(OpenehrRails::Rm::Ehr)
  PATIENTS.each do |ehr_id, subject_name|
    ehr = OpenehrRails::Rm::Ehr.find_by(ehr_id: ehr_id)
    ehr&.update!(subject_id: subject_name)
  end
  puts "[demo_seed] Ehr: #{OpenehrRails::Rm::Ehr.count} records"
end
