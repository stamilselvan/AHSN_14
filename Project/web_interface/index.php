<!DOCTYPE html>
<html lang="en">
	<head>
		<meta charset="UTF-8">
		<title>Transit by TEMPLATED</title>
		<meta http-equiv="refresh" content="5">
		<link rel="stylesheet" type="text/css" href="css/counter.css" />
		<script type="text/javascript" src="js/flipcounter.js"></script>
		
		<!--[if lte IE 8]><script src="js/html5shiv.js"></script><![endif]-->
		<script src="js/jquery.min.js"></script>
		<script src="js/skel.min.js"></script>
		<script src="js/skel-layers.min.js"></script>
		<script src="js/init.js"></script>
		<noscript>
			<link rel="stylesheet" href="css/skel.css" />
			<link rel="stylesheet" href="css/style.css" />
			<link rel="stylesheet" href="css/style-xlarge.css" />
		</noscript>
	</head>
	<body class="landing">
		<!-- Header -->
		<header id="header">
			<!-- <h1><a href="index.html">Home</a></h1> -->
			<nav id="nav">
				<ul>
					<li><a href="index.php?view=product">Temperature</a></li>
					<li><a href="index.php?view=warnings">Warnings</a></li>
					<li><a href="index.php?view=stock-available">Available</a></li>
					<!-- <li><a href="#" class="button special">Sign Up</a></li> -->
				</ul>
			</nav>
		</header>

		<!-- One -->
		<section id="availability" class="wrapper style1 special">
			<div class="container">
				<header class="major">
					<h2>Real-time stock management</h2>
					
				</header>

				<script>
				function counter(i, val) {
					var str = "flip-counter" + i;
					console.log(str, val);
					flipCounter(str, {value:val, inc:0, pace:0, auto:true});
				}
				</script>

				<?php 

					if ($_GET['view'] == "product"){
						productList();
					}

					if ($_GET['view'] == "stock-available"){
					        stockListAvailable();
					}

					if ($_GET['view'] == "warnings"){
					        stockListWarning();
					}
					

					function productList(){
						echo "<h2  class='heading'>Node Temperature</h2>";
						echo "<div class='table-view'> <table class='rwd-table'>";
						echo "<tr><th>Node ID</th><th>Product</th><th>Temperature</th></tr>";

						$con=mysqli_connect("localhost","root","Vxpa8327","inventory_list");
						if (mysqli_connect_errno()) {
							echo "Failed to connect to MySQL: " . mysqli_connect_error();
						}

						#$query = "SELECT ProductID, ProductName, ProductWarningQuantity, ProductWarningTemperature FROM inventory_list.Product";
						#$query = "SELECT productId, nodeId, temperature FROM inventory_list.product";
						$query = "SELECT stockName, nodeId, temperature FROM inventory_list.product join inventory_list.Stock on productId = stockId";
						$result = mysqli_query($con,$query);

						while($row = mysqli_fetch_array($result))
						{
							echo "<tr>";
							echo "<td>" . $row['nodeId'] . "</td>";
							#echo "<td>" . $row['productId'] . "</td>";
							echo "<td>" . $row['stockName'] . "</td>";
							echo "<td>" . $row['temperature'] . "</td>";
							echo "</tr>";
						}
						echo "</table></div>";
					}

					function stockListAvailable(){
						echo "<h2  class='heading'>Stock Availability</h2><div class='row 150%'>";
						
						$con=mysqli_connect("localhost","root","Vxpa8327","inventory_list");
						if (mysqli_connect_errno()) {
					  		echo "Failed to connect to MySQL: " . mysqli_connect_error();
						}

						//$query = "select stockId, stockName, count(productId) as qty from inventory_list.Stock join inventory_list.product on stockId = productId;";
						$query = "SELECT p.productId, COUNT(*) as count, S.StockName FROM product p INNER JOIN Stock S on p.productId = S.StockID GROUP BY p.productId;";
						$result = mysqli_query($con,$query);

						$i = 1;

						while($row = mysqli_fetch_array($result))
						{
							echo "<div class='4u'> <section class='box'> <div id='wrapper$i' class='counter-wrapper'>";
							echo "<div id='flip-counter$i' class='flip-counter'></div>";
							echo "</div><h3>" .$row['StockName']. "</h3></section></div>";
							echo "<script type='text/javascript'>counter( $i ," .$row['count']. ");</script>";
							$i++;
						}

					}

					function stockListWarning(){
						echo "<h2  class='heading'>Stock Warnings</h2>";
						echo "<div id='table-view'> <table class='rwd-table'>";
						echo "<tr><th>Node ID</th><th>Product Name</th><th>Temperature</th></tr>";

						$con=mysqli_connect("localhost","root","Vxpa8327","inventory_list");
						if (mysqli_connect_errno()) {
							echo "Failed to connect to MySQL: " . mysqli_connect_error();
						}

						$query = "select nodeId, stockName, temperature from inventory_list.product join inventory_list.Stock on productId = stockId WHERE warning = 1";
						$result = mysqli_query($con,$query);
						
						$i = 0;
						while($row = mysqli_fetch_array($result))
						{
							echo "<tr>";
							echo "<td>" . $row['nodeId'] . "</td>";
							echo "<td>" . $row['stockName'] . "</td>";
							echo "<td>" . $row['temperature'] . "</td>";
							echo "</tr>";
							++$i;
						}
						echo "</table></div>";
						if($i == 0){
							echo "<h2 class='heading green'>Cool. Everything is alright!</h2>";
							echo "<div class='temp-gif'><img src='img/jumping.gif'></div>";
						}
						else {
							echo "<h2 class='heading red'>Fire!.. Fire!!...Fire!!!</h2>";
							echo "<div class='temp-gif'><img src='img/fire.gif'></div>";
						}
					}
				?>
			</div>
		</section>
	</body>
</html>

