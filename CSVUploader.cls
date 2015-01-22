/* a: michael murphy
 * desc: Controller Extension to allow for CSV insert of any object
 * todo: - Should display a list of everything uploaded if possible
 *       - Account and Equipment should be able to looked up by Name not Id
 *       - RecordType should be looked up from developer name without having
 *           a big query within the for loop... however, must handle different
 *           record types on each row
 * */
 
public class CSV_Parser_ContExt {
  public Blob csvFileBody { get; set; }
  public String csvAsString { get; set; }
  public List<String> csvFileLines { get; set; }
  private List<SObject> sObjList;
  private Schema.SObjectType sObjType;
  private transient Schema.DescribeSObjectResult sObjDesc;
  private Map<String, String> labelApiMap;
 
  public CSV_Parser_ContExt(ApexPages.StandardController sc){
    this.csvFileLines = new List<String>{}; // limited to 1000 elements?
 
    /* derive the type of the sobject from the standard controller */
    this.sObjType = sc.getRecord().getSObjectType();
    this.sObjDesc = sObjType.getDescribe();
 
    /* the csv should have columns with the field labels
     * so need a map to get the api name for insert
     * */
    this.labelApiMap = getObjectLabelApiNameMap(sObjDesc.fields.getMap());
 
    /* generate a list of sobjects of whatever type
     * the standardcontroller is
     * */
    this.sObjList = new List<SObject>();
 
  }
 
  /* get a map of fields label->api for a given object */
  private Map<String, String> getObjectLabelApiNameMap(Map<String, SObjectField> apiLabelMap) {
    Map<String, String> r = new Map<String, String>();
 
    for(String s : apiLabelMap.keySet())
      { r.put(apiLabelMap.get(s).getDescribe().getLabel(), s); }
 
    return r;
  }
 
  /* generate a map of column index -> field labels
   * this is so the user can put the fields in the CSV
   * in any order and we derive the indexes from the labels
   * */
  private Map<Integer, String> generateColumnIndexFieldLabelMap() {
    Map<Integer, String> columnIndexFieldLabelMap = new Map<Integer, String>();
 
    /* the first row should contain the field labels */
    if(csvFileLines.size() > 0) {
      List<String> csvRecordData = csvFileLines[0].split(',');
 
      if(csvRecordData.size() > 0) {
	for(Integer i = 0; i < csvRecordData.size(); i++ )
	  { columnIndexFieldLabelMap.put(i, csvRecordData[i].trim()); } // trim cos last item will have newline
      } else {
	ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR,
						   'Field labels should be contained in the first row of the file'));
      }
    } else {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR,
						 'The file has no rows to insert'));
    }
 
    return columnIndexFieldLabelMap;
  }
 
  /* this is called from the visualforce page to import the CSV itself */
  public void importCSVFile(){
 
    /* I dont trust users to get this right so make sure everything can be caught */
    try {
      csvAsString = csvFileBody.toString();
      csvFileLines = csvAsString.split('\n');
 
      /* generate the column index field label map so we know
       * what data to expect given each field index
       * */
      Map<Integer, String> columnIndexFieldLabelMap = generateColumnIndexFieldLabelMap();
 
      /* iterate through all lines starting after the initial field label row */
      for(Integer i = 1; i < csvFileLines.size(); i++) {
	SObject sObj = sObjType.newSObject(); // create a new generic sObject of whatever type
	List<String> csvRecordData = csvFileLines[i].split(',');
 
	for(Integer j = 0; j < csvRecordData.size(); j++) {
	  String fieldLabel = columnIndexFieldLabelMap.get(j);
	  String data = csvRecordData[j];
 
	  if(data != null && !String.isEmpty(data)) {
	    /* ok so I need to put this little hack in so that
	     * we can handle recordtypeid.  dont want to try
	     * and look this up from the labelapimap
	     * */
	    String apiName = fieldLabel == 'RecordTypeId'
	      ? 'RecordTypeId'
	      : labelApiMap.get(fieldLabel);
                                               
	    /* using the api name we can put the data from
	     * the csv into the object
	     * */
	    sObj.put(apiName, data);
	  }
	}
 
	sObjList.add(sObj);
      }
      insert sObjList;
      ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.INFO, 'The upload was successful.'));
    } catch (Exception e) {
      ApexPages.addMessage(new ApexPages.Message(ApexPages.severity.ERROR,
						 'An error occurred importing data.  Please check the input file. '
						 + e.getMessage()));
    }
  }
}
