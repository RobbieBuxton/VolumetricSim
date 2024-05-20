import pyvista as pv
import numpy as np
from pymongo import MongoClient
from bson import ObjectId

def connect_to_mongo():
    """ Connects to MongoDB and returns the database object. """
    # Creation of MongoClient
    client = MongoClient("mongodb://localhost:27017/", serverSelectionTimeoutMS=5000)
    try:
        client.server_info()  # Force connection on a request as the driver doesn't connect until you attempt to send some data
    except Exception as e:
        print("Unable to connect to the server:", e)
        return None
    # Access database
    mydatabase = client["user_study_db"]

    return mydatabase

def visualize_point_cloud_pyvista(file_path, z_min=0, z_max=500, distance_threshold=1000):
    data = np.loadtxt(file_path, delimiter=',', skiprows=1)

    # Create a mask that includes points close to the eyes or hands
    filtered_data = data
    
    # Normalize z-values for color mapping
    z_normalized = (filtered_data[:, 2] - z_min) / (z_max - z_min)
    z_normalized = np.clip(z_normalized, 0, 1)  # Ensure values are between 0 and 1
    
    point_cloud = pv.PolyData(filtered_data[:, :3])
    plotter = pv.Plotter()
    
    # Use the 'coolwarm' colormap, with colors based on normalized z-values
    plotter.add_points(point_cloud, scalars=z_normalized, cmap="coolwarm", point_size=1.5)
    
    # Define the four points
    width = 34.0
    height = 52.0
    points = np.array([
        [-width/2, 0, 0],
        [width/2, 0, 0],
        [-width/2, height, 0],
        [width/2, height, 0]
    ])
    
    # Add the points to the plotter
    plotter.add_points(points, color='green', point_size=10)

    # Define the rectangle edges
    edges = np.array([
        [points[0], points[1]],
        [points[1], points[3]],
        [points[3], points[2]],
        [points[2], points[0]]
    ])
    
    # Add the rectangle edges to the plotter
    for edge in edges:
        plotter.add_lines(edge, color='yellow', width=5)
    
    plotter.view_xz()
    plotter.camera.position = (1, 1, 0)
    
    plotter.add_axes(interactive=False, line_width=5, labels_off=False)

    plotter.show()


# Helper function to handle MongoDB ObjectId when serializing to JSON
def json_encoder(o):
    if isinstance(o, ObjectId):
        return str(o)
    return o
