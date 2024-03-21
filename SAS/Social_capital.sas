/*==========================================================*/
/*import data*/
proc sql;
%if %sysfunc(exist(WORK.IMPORT)) %then %do;
    drop table WORK.IMPORT;
%end;
%if %sysfunc(exist(WORK.IMPORT,VIEW)) %then %do;
    drop view WORK.IMPORT;
%end;
quit;

FILENAME REFFILE DISK '/shared/home/rpddkpla@memphis.edu/casuser/social_capital_zip.csv';

PROC IMPORT DATAFILE=REFFILE
	DBMS=CSV
	OUT=WORK.IMPORT;
	GETNAMES=YES;
RUN;

PROC CONTENTS DATA=WORK.IMPORT; 
RUN;

/*==========================================================
Step 1: Data Preprocessing
Missing Value Analysis: 
Identify any missing values across all columns and decide on
an imputation strategy (mean, median, mode, or deletion).

Outlier Detection: 
Detect any outliers using statistical measures like the
Interquartile Range (IQR) or Z-scores.

Data Transformation:
Normalize or standardize the data if necessary, 
especially if using algorithms that are sensitive to scale.
(ADVISABLE TO BE DONE AFTER EDA)

Feature Engineering:
Create new features that could be 
significant for prediction, such as interaction terms or ratios.
(OPTIONAL, NEEDS DOMAIN KNOWLEDGE).
==========================================================*/
/*MISSING OBSERVATIONS*/
proc means data=WORK.IMPORT N NMISS MAXDEC=0;
    var _numeric_;
    output out=missing_values_summary(drop=_TYPE_ _FREQ_) 
        n=N nmiss=NMISS;
run;

/* Create a report of the missing values summary */
proc print data=missing_values_summary noobs;
    title "Summary of Missing Values";
run;

/*IMPUTING MISSING OBSERVATIONS*/
/* Median Imputation for Numerical Variables */
proc stdize data=WORK.IMPORT out=WORK.IMPORT_MEDIAN_REPAIRED method=mean reponly;
    var num_below_p50 volunteering_rate_zip civic_organizations_zip
        ec_zip ec_se_zip nbhd_ec_zip ec_grp_mem_zip ec_high_zip ec_high_se_zip
        nbhd_ec_high_zip ec_grp_mem_high_zip exposure_grp_mem_zip exposure_grp_mem_high_zip
        nbhd_exposure_zip bias_grp_mem_zip bias_grp_mem_high_zip nbhd_bias_zip nbhd_bias_high_zip;
run;

/* Verify the imputation */
proc means data=WORK.IMPORT_IMPUTED N NMISS;
    var num_below_p50 volunteering_rate_zip civic_organizations_zip
        ec_zip ec_se_zip nbhd_ec_zip ec_grp_mem_zip ec_high_zip ec_high_se_zip
        nbhd_ec_high_zip ec_grp_mem_high_zip exposure_grp_mem_zip exposure_grp_mem_high_zip
        nbhd_exposure_zip bias_grp_mem_zip bias_grp_mem_high_zip nbhd_bias_zip nbhd_bias_high_zip;
run;


/*==========================================================
Step 2: Exploratory Data Analysis (EDA)
Summary Statistics:
Generate summary statistics to understand the central tendency 
and dispersion of the data.

Correlation Analysis: 
Assess the relationships between variables using correlation analysis.

Visualization: 
Create visualizations such as histograms, 
box plots, scatter plots, and heatmaps to visually inspect 
the data distribution and correlations.
==========================================================*/
/* Summary Statistics for All Numerical Variables Except Identifiers */
proc means data=WORK.IMPORT_IMPUTED N mean std min p25 median p75 max;
    var num_below_p50 volunteering_rate_zip civic_organizations_zip
        ec_zip ec_se_zip nbhd_ec_zip ec_grp_mem_zip ec_high_zip ec_high_se_zip
        nbhd_ec_high_zip ec_grp_mem_high_zip exposure_grp_mem_zip exposure_grp_mem_high_zip
        nbhd_exposure_zip bias_grp_mem_zip bias_grp_mem_high_zip nbhd_bias_zip nbhd_bias_high_zip;
    title "Summary Statistics for Numerical Variables";
run;

/* Correlation Analysis */
proc corr data=WORK.IMPORT_IMPUTED nosimple;
    var num_below_p50 volunteering_rate_zip civic_organizations_zip
        ec_zip ec_se_zip nbhd_ec_zip ec_grp_mem_zip ec_high_zip ec_high_se_zip
        nbhd_ec_high_zip ec_grp_mem_high_zip exposure_grp_mem_zip exposure_grp_mem_high_zip
        nbhd_exposure_zip bias_grp_mem_zip bias_grp_mem_high_zip nbhd_bias_zip nbhd_bias_high_zip;
    title "Correlation Analysis of Numerical Variables";
run;

/* Correlation Analysis Including the Target Variable */
proc corr data=WORK.IMPORT_IMPUTED;
    var ec_zip /* Target Variable */
       num_below_p50 civic_organizations_zip;
    title "Correlation Analysis Including Target Variable";
run;

/* Histogram of the Target Variable */
proc sgplot data=WORK.IMPORT_IMPUTED;
    histogram ec_zip; /* 'ec_zip' is the target variable */
    title "Distribution of Target Variable";
run;

/* Box Plot of Target Variable Against a Categorical Predictor */
/* Replace 'categorical_predictor' with an actual categorical variable name from your dataset */
proc sgplot data=WORK.IMPORT_IMPUTED;
    vbox ec_zip;
    title "Target Variable Boxplot";
run;

/* Pairwise Scatter Plots */
proc sgscatter data=WORK.IMPORT_IMPUTED;
    matrix ec_zip num_below_p50 civic_organizations_zip / diagonal=(kernel);
    title "Pairwise Relationships Including Target Variable";
run;


/*==========================================================
Step 3: Data Partitioning
Splitting the Data: 
Divide the data into training and testing 
(validation) sets to ensure that the model can be assessed on unseen data.
==========================================================*/
/* Ensure the correct partitioning of data into training and testing sets */
proc surveyselect data=WORK.IMPORT_IMPUTED out=WORK.PARTITIONED
    samprate=0.7 /* 70% of the data for training */
    outall /* Include all observations in the output dataset */
    method=SRS /* Simple Random Sampling */
    seed=12345;
run;

/* Splitting based on the Selection Flag */
data WORK.TRAIN WORK.TEST;
    set WORK.PARTITIONED;
    /* 'Selected' is a binary flag variable automatically created by proc surveyselect */
    if Selected = 1 then output WORK.TRAIN;
    else output WORK.TEST;
run;

/* Check the number of observations in each set to confirm successful partition */
proc sql;
    select 'Train' as Set, count(*) as Obs from WORK.TRAIN
    union all
    select 'Test' as Set, count(*) as Obs from WORK.TEST;
quit;




/*==========================================================
Step 4: Feature Selection
Variable Importance: 
Identify which features have the most 
influence on the response variable.
Reduction Techniques: 
Apply dimensionality reduction techniques if necessary 
to reduce the number of features.
==========================================================*/
/* Variable Importance */
proc varclus data=WORK.TRAIN;
   var num_below_p50 pop2018 ec_se_zip nbhd_ec_zip ec_grp_mem_zip 
       ec_high_zip ec_high_se_zip nbhd_ec_high_zip ec_grp_mem_high_zip 
       exposure_grp_mem_zip exposure_grp_mem_high_zip nbhd_exposure_zip 
       bias_grp_mem_zip bias_grp_mem_high_zip nbhd_bias_zip nbhd_bias_high_zip 
       clustering_zip support_ratio_zip volunteering_rate_zip civic_organizations_zip;
run;

/* Create X and y sets with the selected features
Selected: variables that have a relatively high R-squared within their own cluster 
and that are less correlated with other clusters. */

/* X features*/
data WORK.PREDICTORS;
    set WORK.TRAIN;
    keep nbhd_ec_zip ec_grp_mem_zip ec_high_zip nbhd_ec_high_zip
         exposure_grp_mem_zip exposure_grp_mem_high_zip nbhd_exposure_zip
         num_below_p50 pop2018 ec_se_zip bias_grp_mem_zip nbhd_bias_zip
         ec_grp_mem_high_zip ec_high_se_zip bias_grp_mem_high_zip support_ratio_zip;
run;

/*y target variable*/
data WORK.RESPONSE;
    set WORK.TRAIN;
    keep ec_zip;
run;


/*==========================================================
Step 5: Model Building
Model Selection: Choose appropriate modeling techniques. 
Random Forest and Neural Networks are chosen.

Model Training: Train the models on the training set.
==========================================================*/
/*Random Forest*/
proc hpforest data=WORK.TRAIN;
    /* Specify your target and input variables appropriately */
    target ec_zip; 
    input nbhd_ec_zip ec_grp_mem_zip ec_high_zip nbhd_ec_high_zip
          exposure_grp_mem_zip exposure_grp_mem_high_zip nbhd_exposure_zip
          num_below_p50 pop2018 ec_se_zip bias_grp_mem_zip nbhd_bias_zip
          ec_grp_mem_high_zip ec_high_se_zip bias_grp_mem_high_zip support_ratio_zip;
         
run;

/* Simple Regression Analysis */
proc reg data=WORK.TRAIN;
    model ec_zip = nbhd_ec_zip ec_grp_mem_zip ec_high_zip nbhd_ec_high_zip
                   exposure_grp_mem_zip exposure_grp_mem_high_zip nbhd_exposure_zip
                   num_below_p50 pop2018 ec_se_zip bias_grp_mem_zip nbhd_bias_zip
                   ec_grp_mem_high_zip ec_high_se_zip bias_grp_mem_high_zip support_ratio_zip;
    /* Output predicted values and residuals */
    output out=WORK.PRED p=predicted r=residual;
run;
