# Gson reads the API v3 model fields and creates instances through reflection.
# Keep only these wire-model names, fields and constructors; other app code can
# still be renamed, shrunk and optimized. Generic types are needed for lists.
-keepattributes Signature
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.TrailsData { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.Location { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.Coordinates { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.Landmark { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.Trail { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.TrailEndpoint { <fields>; <init>(...); }
-keep,allowoptimization class org.warringtontownship.parks.android.data.model.TrailCoordinate { <fields>; <init>(...); }
